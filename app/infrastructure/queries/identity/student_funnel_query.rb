# 🔌 INFRA · Queries::Identity::StudentFunnelQuery
# Rôle : entonnoir AARRR des élèves (inscrits, notion, exercice, réussis 1/2/5, délai, rétention J1/J7/J30, revenu) en 3 requêtes
# ADR  : 0049, 0062, 0085, 0106, 0126 · UDR : 0175 · chantier entonnoir-aarrr (PRD §3 : les définitions)
module Queries
  module Identity
    class StudentFunnelQuery
      # La voie d'arrivée est celle de la première adhésion ; « none » : aucune adhésion. code = ancien code de classe (ADR-0085).
      CHANNELS = %w[standard link code none].freeze
      GROUPS = { alone: %w[standard], classroom: %w[link code], none: %w[none] }.freeze
      RETENTION_DAYS = [ 1, 7, 30 ].freeze
      # Le plus petit score qui « réussit » au sens de Grading.reaches? (note sur 20, ADR-0106) : 48, pas 50.
      PASS_SCORE = (0..100).find { Entities::Assessment::Grading.reaches?(it, Entities::Assessment::Grading::PASS_THRESHOLD) }
      STEPS = %i[signed_up read_essential started passed_one passed_two passed_five].freeze

      Steps = Data.define(*STEPS) do
        def self.zero = new(**STEPS.index_with(0))
        def +(other) = self.class.new(**STEPS.to_h { [ it, public_send(it) + other.public_send(it) ] })
        def to_a = STEPS.map { public_send(it) }
        def rate(step) = signed_up.zero? ? nil : public_send(step).fdiv(signed_up)
      end
      # eligible : élèves dont J+n est passé ; retained : ceux d'entre eux revenus à J+n ou plus tard.
      Retention = Data.define(:eligible, :retained) do
        def self.zero = new(eligible: 0, retained: 0)
        def +(other) = self.class.new(eligible: eligible + other.eligible, retained: retained + other.retained)
        def rate = eligible.zero? ? nil : retained.fdiv(eligible)
      end
      WeekRow = Data.define(:week_on, :channel, :steps, :retention)
      # partial : la semaine commence avant la période, seuls ses inscrits depuis le début de la période sont comptés.
      Cohort = Data.define(:week_on, :signed_up, :retention, :partial)
      Revenue = Data.define(:activated_cards, :amount_xof, :subscribed_students, :beta_open)
      # groups : { alone:, classroom:, none: } → Steps ; median_activation_days : mêmes clés et :total, nil sans activé.
      Report = Data.define(:groups, :total, :median_activation_days, :cohorts, :revenue)

      PASSED = "e.status = 'completed' AND e.score_percent >= :pass_score".freeze
      GROUP_OF = "CASE f.channel WHEN 'standard' THEN 'alone' WHEN 'none' THEN 'none' ELSE 'classroom' END".freeze
      # Un fait par élève inscrit dans la fenêtre, chacun lu sur son index (student_id). Les traces datées sont les seules
      # sûres : essential_reads.last_read_at est écrasé, d'où une rétention « revenu à J+n ou plus tard » (PRD §3).
      FACTS = <<~SQL.squish.freeze
        WITH s AS (
          SELECT u.id, u.created_at,
                 COALESCE((SELECT cs.joined_via FROM classroom_students cs WHERE cs.student_id = u.id ORDER BY cs.id LIMIT 1), 'none') AS channel
            FROM users u
           WHERE u.role = 'student' AND u.anonymized_at IS NULL AND u.created_at >= :from AND u.created_at < :to
        ), f AS (
          SELECT s.id, s.created_at, s.channel,
                 EXISTS (SELECT 1 FROM essential_reads r WHERE r.student_id = s.id) AS has_read,
                 EXISTS (SELECT 1 FROM exercise_sessions e WHERE e.student_id = s.id) AS has_started,
                 (SELECT COUNT(DISTINCT e.exercise_id) FROM exercise_sessions e WHERE e.student_id = s.id AND #{PASSED}) AS passed,
                 (SELECT MIN(e.completed_at) FROM exercise_sessions e WHERE e.student_id = s.id AND #{PASSED}) AS first_pass_at,
                 GREATEST(
                   (SELECT MAX(r.last_read_at) FROM essential_reads r WHERE r.student_id = s.id),
                   (SELECT MAX(GREATEST(e.started_at, e.completed_at)) FROM exercise_sessions e WHERE e.student_id = s.id),
                   (SELECT MAX(a.answered_at) FROM question_attempts a JOIN exercise_sessions e ON e.id = a.exercise_session_id
                     WHERE e.student_id = s.id)
                 ) AS last_active_at
            FROM s
        )
      SQL
      RETAINED = RETENTION_DAYS.map do |days|
        due = "f.created_at + INTERVAL '#{days} days'"
        "COUNT(*) FILTER (WHERE #{due} <= :now) AS eligible_#{days}, " \
          "COUNT(*) FILTER (WHERE #{due} <= :now AND f.last_active_at >= #{due}) AS retained_#{days}"
      end.join(", ").freeze
      # Semaine du lundi ; created_at est en UTC, l'heure d'Abidjan aussi.
      WEEKLY = <<~SQL.squish.freeze
        #{FACTS}
        SELECT date_trunc('week', f.created_at)::date AS week_on, f.channel,
               COUNT(*) AS signed_up, COUNT(*) FILTER (WHERE f.has_read) AS read_essential,
               COUNT(*) FILTER (WHERE f.has_started) AS started, COUNT(*) FILTER (WHERE f.passed >= 1) AS passed_one,
               COUNT(*) FILTER (WHERE f.passed >= 2) AS passed_two, COUNT(*) FILTER (WHERE f.passed >= 5) AS passed_five,
               #{RETAINED}
          FROM f GROUP BY 1, 2 ORDER BY 1, 2
      SQL
      # Un succès daté d'avant l'inscription (reprise de données) compte 0 jour. ROLLUP : la ligne de groupe NULL est le total.
      MEDIANS = <<~SQL.squish.freeze
        #{FACTS}
        SELECT #{GROUP_OF} AS grp,
               percentile_cont(0.5) WITHIN GROUP (ORDER BY GREATEST(0, EXTRACT(EPOCH FROM (f.first_pass_at - f.created_at))) / 86400.0) AS days
          FROM f WHERE f.first_pass_at IS NOT NULL GROUP BY ROLLUP (1)
      SQL
      REVENUE = <<~SQL.squish.freeze
        SELECT COUNT(*) FILTER (WHERE c.activated_at >= :from AND c.activated_at < :to) AS cards,
               COALESCE(SUM(c.price_xof) FILTER (WHERE c.activated_at >= :from AND c.activated_at < :to), 0) AS amount,
               COUNT(DISTINCT c.student_id) FILTER (WHERE c.valid_until >= :today AND u.anonymized_at IS NULL) AS subscribed
          FROM billing_activation_cards c LEFT JOIN users u ON u.id = c.student_id WHERE c.state = 'activated'
      SQL

      # Une ligne par (semaine, voie) non vide, dans l'ordre. Lue par la page Croissance et par `entonnoir:brut`.
      def weekly(from:, to:, now: Time.current)
        select_all(WEEKLY, from:, to:, now:, pass_score: PASS_SCORE).map do |row|
          WeekRow.new(week_on: row.fetch("week_on").to_date, channel: row.fetch("channel"),
                      steps: Steps.new(**STEPS.to_h { [ it, row.fetch(it.to_s).to_i ] }),
                      retention: RETENTION_DAYS.to_h do |days|
                        [ days, Retention.new(eligible: row.fetch("eligible_#{days}").to_i, retained: row.fetch("retained_#{days}").to_i) ]
                      end)
        end
      end

      def call(from:, to:, now: Time.current)
        rows = weekly(from:, to:, now:)
        groups = GROUPS.transform_values { |channels| sum_steps(rows.select { it.channel.in?(channels) }) }
        Report.new(groups:, total: sum_steps(rows), median_activation_days: medians(from:, to:),
                   cohorts: cohorts(rows, from), revenue: revenue(from:, to:, today: now.to_date))
      end

      private

      def select_all(sql, **binds) = Orm::User.connection.select_all(Orm::User.sanitize_sql_array([ sql, binds ])).to_a

      def sum_steps(rows) = rows.sum(Steps.zero, &:steps)

      def cohorts(rows, from)
        rows.group_by(&:week_on).map do |week_on, week|
          Cohort.new(week_on:, signed_up: sum_steps(week).signed_up, partial: week_on.in_time_zone < from,
                     retention: RETENTION_DAYS.to_h { |days| [ days, week.sum(Retention.zero) { it.retention.fetch(days) } ] })
        end
      end

      def medians(from:, to:)
        # Sans activé, ROLLUP rend quand même sa ligne de total, à NULL.
        select_all(MEDIANS, from:, to:, pass_score: PASS_SCORE).filter_map do |row|
          [ (row.fetch("grp") || "total").to_sym, row.fetch("days").to_f ] if row.fetch("days")
        end.to_h
      end

      def revenue(from:, to:, today:)
        row = select_all(REVENUE, from:, to:, today:).first
        beta_ends_on = Entities::Billing::Offer::BETA_ENDS_ON
        Revenue.new(activated_cards: row.fetch("cards").to_i, amount_xof: row.fetch("amount").to_i,
                    subscribed_students: row.fetch("subscribed").to_i, beta_open: beta_ends_on.nil? || today < beta_ends_on)
      end
    end
  end
end

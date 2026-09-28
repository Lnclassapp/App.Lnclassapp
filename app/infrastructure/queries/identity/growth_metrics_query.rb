# 🔌 INFRA · Queries::Identity::GrowthMetricsQuery
# Rôle : indicateurs de croissance d'une période (partages, inscriptions, conversion, k, cycle, parrains, élèves, classement) en 4 requêtes
# ADR  : 0006, 0049, 0063 · UDR : 0050
module Queries
  module Identity
    class GrowthMetricsQuery
      # link_signups : parrainages par lien seulement ; la conversion par partage ne compte pas ceux d'un garant (m7).
      Row = Data.define(:shares, :teacher_signups, :referred_signups, :link_signups, :viral, :viral_cycle_days, :top_referrers,
                        :students_joined, :active_teachers, :schools_leaderboard, :pending_count, :oldest_pending) do
        def conversion_rate = shares.zero? ? nil : link_signups.fdiv(shares)
        def students_per_teacher = active_teachers.zero? ? nil : students_joined.fdiv(active_teachers)
      end
      Referrer = Data.define(:name, :school_name, :referrals_count)
      SchoolRow = Data.define(:public_id, :name, :drena_name, :teachers_count)
      PendingRow = Data.define(:school_public_id, :school_name, :created_at)

      TOP = 5
      LEADERBOARD = 10
      IN_PERIOD = "created_at >= :from AND created_at < :to".freeze
      # Un compte en attente ou refusé n'est pas (encore) un enseignant : ni inscription, ni cohorte (m7).
      VALIDATED = "NOT EXISTS (SELECT 1 FROM school_join_requests j WHERE j.teacher_id = u.id AND j.status <> 'approved')".freeze
      COHORT = "u.role = 'teacher' AND u.created_at >= :from AND u.created_at < :to AND #{VALIDATED}".freeze
      FULL_NAME = Arel.sql("users.first_name || ' ' || users.last_name")
      # Une seule lecture pour tous les compteurs : des sous-requêtes scalaires, chacune sur son index.
      COUNTERS = <<~SQL.squish.freeze
        SELECT
          (SELECT COUNT(*) FROM referral_shares WHERE #{IN_PERIOD}) AS shares,
          (SELECT COUNT(*) FROM users u WHERE #{COHORT}) AS teacher_signups,
          (SELECT COUNT(*) FROM referrals WHERE #{IN_PERIOD}) AS referred_signups,
          (SELECT COUNT(*) FROM referrals WHERE source = 'link' AND #{IN_PERIOD}) AS link_signups,
          (SELECT COUNT(*) FROM referral_shares s JOIN users u ON u.id = s.user_id WHERE #{COHORT}) AS cohort_shares,
          (SELECT COUNT(*) FROM referrals r JOIN users u ON u.id = r.referrer_id WHERE r.source = 'link' AND #{COHORT}) AS cohort_referees,
          (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (e.created_at - p.created_at)) / 86400.0)
             FROM referrals r JOIN users p ON p.id = r.referrer_id JOIN users e ON e.id = r.referee_id
            WHERE r.created_at >= :from AND r.created_at < :to) AS viral_cycle_days,
          (SELECT COUNT(DISTINCT student_id) FROM classroom_students WHERE joined_at >= :from AND joined_at < :to) AS students_joined,
          (SELECT COUNT(DISTINCT teacher_id) FROM teacher_schools WHERE "primary") AS active_teachers,
          (SELECT COUNT(*) FROM school_join_requests WHERE status = 'pending') AS pending_count
      SQL

      def call(from:, to:)
        counts = Orm::User.connection.select_one(Orm::User.sanitize_sql_array([ COUNTERS, { from:, to: } ]))
        integer = ->(key) { counts.fetch(key).to_i }
        Row.new(shares: integer["shares"], teacher_signups: integer["teacher_signups"], referred_signups: integer["referred_signups"],
                link_signups: integer["link_signups"],
                viral: Entities::Identity::ViralCoefficient.new(cohort_size: integer["teacher_signups"], shares: integer["cohort_shares"],
                                                                referees: integer["cohort_referees"]),
                viral_cycle_days: counts.fetch("viral_cycle_days")&.to_f, top_referrers: top_referrers(from, to),
                students_joined: integer["students_joined"], active_teachers: integer["active_teachers"],
                schools_leaderboard:, pending_count: integer["pending_count"], oldest_pending:)
      end

      private

      def top_referrers(from, to)
        Orm::Referral.joins(:referrer)
                     .joins("LEFT JOIN teacher_schools ON teacher_schools.teacher_id = referrals.referrer_id AND teacher_schools.primary")
                     .joins("LEFT JOIN schools ON schools.id = teacher_schools.school_id")
                     .where(created_at: from...to).group("referrals.referrer_id", "users.first_name", "users.last_name", "schools.name")
                     .order(Arel.sql("COUNT(*) DESC"), "users.last_name", "users.first_name").limit(TOP)
                     .pluck(FULL_NAME, "schools.name", Arel.sql("COUNT(*)")).map { Referrer.new(*it) }
      end

      def schools_leaderboard
        Orm::TeacherSchool.joins(school: :drena).where(primary: true, schools: { status: "active" })
                          .group("schools.id", "schools.public_id", "schools.name", "drenas.name")
                          .order(Arel.sql("COUNT(*) DESC"), "schools.name").limit(LEADERBOARD)
                          .pluck("schools.public_id", "schools.name", "drenas.name", Arel.sql("COUNT(*)")).map { SchoolRow.new(*it) }
      end

      def oldest_pending
        Orm::SchoolJoinRequest.joins(:school).where(status: "pending").order(:created_at, :id).limit(TOP)
                              .pluck("schools.public_id", "schools.name", "school_join_requests.created_at").map { PendingRow.new(*it) }
      end
    end
  end
end

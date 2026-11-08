# 🔌 INFRA · Queries::Billing::CashboxQuery
# Rôle : la caisse de l'équipe, lue à la demande (CQRS) : par point relais, commissions de la semaine, cumul par école ; requêtes agrégées
# ADR  : 0126 (contexte billing, §4.7) · UDR : 0159 §3.1
module Queries
  module Billing
    class CashboxQuery
      PAST_WEEKS = 8
      # Vendredi de la semaine d'une activation : la date moins le nombre de jours écoulés depuis le vendredi (Africa/Abidjan = UTC).
      WEEK_START_SQL = "(activated_at::date - ((EXTRACT(DOW FROM activated_at)::int + 2) % 7))".freeze

      RelayPoint = Data.define(:id, :public_id, :name, :active)
      RelayLine = Data.define(:id, :public_id, :name, :issued_count, :activated_count, :cancelled_count, :in_circulation, :remitted_xof,
                              :due_xof)
      WeekLine = Data.define(:name, :activations, :commission_xof)
      Week = Data.define(:week, :lines, :total_activations, :total_xof)
      SchoolLine = Data.define(:id, :name, :subscriptions, :commission_xof)
      Cashbox = Data.define(:relays, :last_week, :past_weeks, :current_week_activations, :schools)

      # at : l'instant de lecture. → Cashbox
      def call(at:)
        relay_points = self.relay_points
        weeks = CommissionWeekCounts.new(at:, names: relay_points.to_h { [ it.id, it.name ] })
        Cashbox.new(relays: relay_lines(relay_points), last_week: weeks.last_week, past_weeks: weeks.past_weeks,
                    current_week_activations: weeks.current_week_activations, schools: school_lines)
      end

      # Les points relais, par nom : le choix du point relais d'un versement. → [RelayPoint]
      def relay_points
        Orm::Billing::RelayPoint.order(:name, :id).pluck(:id, :public_id, :name, :active).map { RelayPoint.new(*it) }
      end

      private

      def relay_lines(relay_points)
        cards = card_totals
        remitted = Orm::Billing::Remittance.group(:relay_point_id).sum(:amount_xof)
        lines = relay_points.map { relay_line(it, cards.fetch(it.id, [ 0, 0, 0, 0, 0 ]), remitted.fetch(it.id, 0)) }
        lines.sort_by { [ -it.due_xof, it.name ] }
      end

      def relay_line(relay_point, totals, remitted_xof)
        issued_total, activated, cancelled, circulating, owed = totals
        RelayLine.new(id: relay_point.id, public_id: relay_point.public_id, name: relay_point.name, issued_count: issued_total,
                      activated_count: activated, cancelled_count: cancelled, in_circulation: circulating, remitted_xof:,
                      due_xof: owed - remitted_xof)
      end

      # Une seule requête pour toutes les cartes : [remises, activées, annulées, en circulation, dû brut] par point relais.
      def card_totals
        Orm::Billing::ActivationCard.group(:relay_point_id).pluck(
          :relay_point_id, Arel.sql("COUNT(*)"),
          Arel.sql("COUNT(*) FILTER (WHERE state = 'activated')"),
          Arel.sql("COUNT(*) FILTER (WHERE state = 'cancelled')"),
          Arel.sql("COUNT(*) FILTER (WHERE state = 'issued')"),
          Arel.sql("COALESCE(SUM(price_xof) FILTER (WHERE state = 'activated'), 0)")
        ).to_h { |id, *totals| [ id, totals.map(&:to_i) ] }
      end

      def school_lines
        counts = Orm::Billing::ActivationCard.where(state: "activated").where("billing_activation_cards.price_xof > 0")
                                             .where.not(school_id: nil).joins(:school).group("schools.id", "schools.name").count
        counts.map { |(id, name), count| SchoolLine.new(id:, name:, subscriptions: count, commission_xof: count * Entities::Billing::Offer::SCHOOL_COMMISSION_XOF) }
              .sort_by { [ -it.commission_xof, it.name ] }
      end

      # Les activations payantes de la semaine en cours, de la dernière semaine terminée et des 8 précédentes, par point relais :
      # une seule requête groupée sur toute la fenêtre.
      class CommissionWeekCounts
        def initialize(at:, names:)
          @names = names
          @last = Entities::Billing::CommissionWeek.previous(at:)
          @current = Entities::Billing::CommissionWeek.containing(at)
          @past = Entities::Billing::CommissionWeek.recent(PAST_WEEKS + 1, at:).drop(1)
          @counts = counts(from: (@past.last || @last).starts_at, to: @current.ends_at)
        end

        def last_week = week(@last)
        def past_weeks = @past.map { week(it) }
        def current_week_activations = @counts.sum { |(_, start), count| start == @current.starts_on ? count : 0 }

        private

        def counts(from:, to:)
          Orm::Billing::ActivationCard.where(state: "activated", activated_at: from...to).where("price_xof > 0")
                                      .group(:relay_point_id, Arel.sql(WEEK_START_SQL)).count
        end

        def week(week)
          lines = @counts.filter_map do |(relay_point_id, start), count|
            WeekLine.new(name: @names.fetch(relay_point_id), activations: count, commission_xof: week.commission_xof(count)) if start == week.starts_on
          end.sort_by { [ -it.activations, it.name ] }
          total = lines.sum(&:activations)
          Week.new(week:, lines:, total_activations: total, total_xof: week.commission_xof(total))
        end
      end
    end
  end
end

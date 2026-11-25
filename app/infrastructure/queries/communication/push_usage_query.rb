# 🔌 INFRA · Queries::Communication::PushUsageQuery
# Rôle : l'usage des notifications pour le pilotage de l'équipe : élèves abonnés, abonnements, retraits, envois de la semaine par motif
# ADR  : 0146 · UDR : 0186 (§3.4) · trois requêtes, aucun nom
module Queries
  module Communication
    class PushUsageQuery
      WINDOW = 7.days
      Usage = Data.define(:students, :subscriptions, :turned_off, :sent, :failed, :by_motive)

      # sent : envois partis (`delivered`) ; failed : `failed` et `gone` ; un statut provisoire (retry, disabled, not_configured) ne compte pas.
      # by_motive : { motif => envois partis }, motifs sans envoi absents.
      def call(now: Time.current)
        students, subscriptions = Orm::Communication::PushSubscription.pick(Arel.sql("COUNT(DISTINCT user_id)"), Arel.sql("COUNT(*)"))
        turned_off = Orm::Communication::PushPreference.where.not(turned_off_at: nil).count
        counts = Orm::Communication::PushDelivery.where(sent_at: (now - WINDOW)..now).group(:motive, :status).count
        Usage.new(students:, subscriptions:, turned_off:, sent: total(counts, %w[delivered]), failed: total(counts, %w[failed gone]),
                  by_motive: by_motive(counts))
      end

      private

      def total(counts, statuses) = counts.sum { |(_, status), count| statuses.include?(status) ? count : 0 }

      def by_motive(counts)
        counts.select { |(_, status), _| status == "delivered" }.to_h { |(motive, _), count| [ motive, count ] }
      end
    end
  end
end

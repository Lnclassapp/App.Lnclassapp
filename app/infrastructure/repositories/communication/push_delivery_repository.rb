# 🔌 INFRA · Repositories::Communication::PushDeliveryRepository
# Rôle : envois de notifications en base (push_deliveries, une ligne par élève, motif et clé d'objet) : anti-doublon, intervalle, purge à 90 jours
# ADR  : 0146 (§4.1, §4.2) · adaptateur de Ports::Communication::PushDeliveryRepositoryPort
module Repositories
  module Communication
    class PushDeliveryRepository
      include Ports::Communication::PushDeliveryRepositoryPort

      # Statuts qui ferment le motif : il est parti, l'abonnement est mort, ou les trois essais sont épuisés.
      FINAL = %w[delivered gone failed].freeze

      # Un seul ordre SQL : l'écriture remplace une ligne provisoire et laisse une ligne définitive intacte (RETURNING vide).
      UPSERT = <<~SQL.squish.freeze
        INSERT INTO push_deliveries (user_id, motive, object_key, status, sent_at)
        VALUES (:user_id, :motive, :object_key, :status, :at)
        ON CONFLICT (user_id, motive, object_key)
        DO UPDATE SET status = EXCLUDED.status, sent_at = EXCLUDED.sent_at
        WHERE push_deliveries.status NOT IN (:final)
        RETURNING id
      SQL

      def record(user_id:, motive:, object_key:, status:, at:)
        sql = Orm::Communication::PushDelivery.sanitize_sql_array([ UPSERT, { user_id:, motive:, object_key:, status:, at:, final: FINAL } ])
        connection = Orm::Communication::PushDelivery.connection
        # Un SELECT … RETURNING n'invalide pas le cache de requêtes (actif dans un job) : sent? et last_sent_at doivent voir l'écriture.
        connection.select_value(sql).present?.tap { connection.clear_query_cache }
      end

      def sent?(user_id:, motive:, object_key:)
        Orm::Communication::PushDelivery.where(user_id:, motive:, object_key:, status: FINAL).exists?
      end

      def last_sent_at(user_id:) = Orm::Communication::PushDelivery.where(user_id:, status: "delivered").maximum(:sent_at)

      # Le jour d'Abidjan est le jour UTC (GMT+0, sans heure d'été).
      def sent_count(user_id:, on_date:)
        Orm::Communication::PushDelivery.where(user_id:, status: "delivered", sent_at: on_date.in_time_zone("UTC").all_day).count
      end

      def purge_before(before:) = Orm::Communication::PushDelivery.where(sent_at: ...before).delete_all
    end
  end
end

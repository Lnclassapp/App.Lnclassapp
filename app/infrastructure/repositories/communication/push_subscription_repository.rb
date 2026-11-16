# 🔌 INFRA · Repositories::Communication::PushSubscriptionRepository
# Rôle : abonnements Web Push en base (push_subscriptions), uniques par adresse : une adresse connue change de propriétaire
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.1, §4.2) · adaptateur de Ports::Communication::PushSubscriptionRepositoryPort
module Repositories
  module Communication
    class PushSubscriptionRepository
      include Ports::Communication::PushSubscriptionRepositoryPort

      # Un seul ordre SQL (ON CONFLICT sur l'adresse) : deux appareils ou deux comptes en même temps ne lèvent rien, le dernier gagne.
      def register(user_id:, session_id:, endpoint:, p256dh:, auth:)
        now = Time.current
        # Horodatages explicites : l'upsert de Rails ne touche `updated_at` que si une colonne change, or le réenregistrement le remet à jour (purge).
        Orm::Communication::PushSubscription.upsert({ user_id:, session_id:, endpoint:, p256dh:, auth:, failure_count: 0, created_at: now, updated_at: now },
                                                    unique_by: :endpoint, record_timestamps: false)
        to_entity(Orm::Communication::PushSubscription.find_by!(endpoint:))
      end

      def delete_oldest_beyond(user_id:, limit:)
        excess = Orm::Communication::PushSubscription.where(user_id:).order(updated_at: :desc, id: :desc).offset(limit).pluck(:id)
        Orm::Communication::PushSubscription.where(id: excess).delete_all
      end

      def for_user(user_id:) = Orm::Communication::PushSubscription.where(user_id:).order(:id).map { to_entity(it) }

      def delete(id:) = Orm::Communication::PushSubscription.where(id:).delete_all

      def delete_for_user(user_id:) = Orm::Communication::PushSubscription.where(user_id:).delete_all

      def reattach_session(from_session_id:, to_session_id:)
        Orm::Communication::PushSubscription.where(session_id: from_session_id).update_all(session_id: to_session_id)
      end

      # `where.not(session_id:)` écarterait les NULL en SQL : ils sont inclus à part.
      def delete_for_user_except_session(user_id:, session_id:)
        scope = Orm::Communication::PushSubscription.where(user_id:)
        scope.where.not(session_id:).or(scope.where(session_id: nil)).delete_all
      end

      def delete_for_sessions(session_ids:) = Orm::Communication::PushSubscription.where(session_id: session_ids).delete_all

      def record_success(id:, at:) = Orm::Communication::PushSubscription.where(id:).update_all(last_success_at: at, failure_count: 0)

      def record_failure(id:)
        scope = Orm::Communication::PushSubscription.where(id:)
        scope.update_all("failure_count = failure_count + 1")
        scope.pick(:failure_count).to_i
      end

      def reset_failures(id:) = Orm::Communication::PushSubscription.where(id:).update_all(failure_count: 0)

      def delete_stale(before:)
        Orm::Communication::PushSubscription.where("COALESCE(last_success_at, updated_at) < ?", before).delete_all
      end

      private

      def to_entity(row)
        Entities::Communication::PushSubscription.new(id: row.id, user_id: row.user_id, session_id: row.session_id, endpoint: row.endpoint,
                                                      p256dh: row.p256dh, auth: row.auth, last_success_at: row.last_success_at,
                                                      failure_count: row.failure_count)
      end
    end
  end
end

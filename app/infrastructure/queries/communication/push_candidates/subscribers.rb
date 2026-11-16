# 🔌 INFRA · Queries::Communication::PushCandidates::Subscribers
# Rôle : les abonnements des élèves qui peuvent être notifiés (non anonymisés, non coupés), limités à `user_ids` si donnés (relecture avant envoi)
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.7)
module Queries
  module Communication
    class PushCandidates
      module Subscribers
        # → ActiveRecord::Relation d'Orm::Communication::PushSubscription ; nil = tous les élèves.
        def self.scope(user_ids)
          scope = Orm::Communication::PushSubscription.joins(:user).where(users: { anonymized_at: nil })
                                                      .where.not(user_id: Orm::Communication::PushPreference.where.not(turned_off_at: nil).select(:user_id))
          user_ids.nil? ? scope : scope.where(user_id: user_ids)
        end
      end
    end
  end
end

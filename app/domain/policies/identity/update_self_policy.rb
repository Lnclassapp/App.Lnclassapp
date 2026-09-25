# 🧠 DOMAINE · Policies::Identity::UpdateSelfPolicy
# Rôle : modifier son propre compte, et seulement le sien ; aucun appelant en V1
# ADR  : 0028
module Policies
  module Identity
    class UpdateSelfPolicy
      # target : Entities::Identity::User
      def call(actor:, target:)
        return Shared::Result.success if actor && target.id == actor.user_id

        Shared::Result.failure(:forbidden)
      end
    end
  end
end

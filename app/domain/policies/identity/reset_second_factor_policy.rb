# 🧠 DOMAINE · Policies::Identity::ResetSecondFactorPolicy
# Rôle : un membre de l'équipe réinitialise le second facteur d'un autre membre, jamais le sien
# ADR  : 0028, 0031
module Policies
  module Identity
    class ResetSecondFactorPolicy
      def call(actor:, target:)
        return Shared::Result.success if actor&.team? && target.team? && target.id != actor.user_id

        Shared::Result.failure(:forbidden)
      end
    end
  end
end

# 🧠 DOMAINE · Policies::Identity::DeleteUserPolicy
# Rôle : supprimer (anonymiser) un compte : l'équipe ; aucun appelant en V1
# ADR  : 0028, 0038
module Policies
  module Identity
    class DeleteUserPolicy
      def call(actor:, target: nil)
        return Shared::Result.success if actor&.team?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end

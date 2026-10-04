# 🧠 DOMAINE · Policies::Identity::DeleteUserPolicy
# Rôle : supprimer (anonymiser) un compte sur demande : l'équipe `admin` seule (matrice de l'ADR-0038), et en V1 un compte élève
# ADR  : 0028, 0036, 0038
module Policies
  module Identity
    class DeleteUserPolicy
      # target : Entities::Identity::User, ou nil pour savoir si l'acteur peut traiter une demande (le geste s'affiche).
      # Enseignant, direction et équipe : leurs rattachements ne sont pas encore traités par l'anonymisation (lot R).
      def call(actor:, target: nil)
        return Shared::Result.failure(:forbidden) unless actor&.team? && actor.team_role == "admin"
        return Shared::Result.failure(:forbidden) unless target.nil? || target.student?

        Shared::Result.success
      end
    end
  end
end

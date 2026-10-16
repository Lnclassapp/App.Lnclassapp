# 🧠 DOMAINE · Policies::School::RegenerateCodesInBulkPolicy
# Rôle : lancer une régénération de masse (codes d'établissement, liens des classes) : membre admin de l'équipe seulement
# ADR  : 0057, 0085, 0096 · le geste un par un garde sa policy (ManageSchoolStructurePolicy, ManageClassroomMembersPolicy)
module Policies
  module School
    class RegenerateCodesInBulkPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team? && actor.team_role == "admin"

        Shared::Result.failure(:forbidden)
      end
    end
  end
end

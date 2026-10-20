# 🧠 DOMAINE · Policies::Identity::ManageOwnMaterialsPolicy
# Rôle : un enseignant remplace ses matières, les siennes seulement, dans son établissement courant ; tout autre rôle est refusé
# ADR  : 0055, 0094 (§4.2), 0103 (§4.4)
module Policies
  module Identity
    class ManageOwnMaterialsPolicy
      # Le compte et l'établissement viennent de l'acteur (route sans identifiant) : rien d'autre à comparer.
      # Sans établissement courant (écran d'attente), il n'a aucune liste à modifier.
      def call(actor:)
        return Shared::Result.success if actor&.teacher? && actor.school_id

        Shared::Result.failure(:forbidden)
      end
    end
  end
end

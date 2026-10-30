# 🧠 DOMAINE · Ports::Assessment::PendingAssignmentRepositoryPort
# Rôle : contrat de lecture « ce devoir est encore à rendre » : l'exercice est assigné à l'élève et il n'en a pas rendu de copie
# ADR  : XXXX-sujets-de-devoir-et-verification-sur-la-feuille (§4), 0048 · UDR : XXXX-feuilles-prepare-interros-et-devoirs §3 (devoir à rendre)
module Ports
  module Assessment
    module PendingAssignmentRepositoryPort
      # Parmi ces exercices, ceux que l'élève doit encore rendre : une assignation active de sa classe principale (active), et aucune copie
      # terminée rattachée à cette assignation. → Set[String] (public_id), vide sans devoir à rendre
      def pending_exercise_public_ids(student_id:, exercise_public_ids:)
        raise NotImplementedError, "#{self.class} doit implémenter #pending_exercise_public_ids"
      end
    end
  end
end

# 🧠 DOMAINE · Ports::Assessment::LearningDataEraserPort
# Rôle : contrat de l'effacement des résultats d'un élève dont le compte est supprimé sur demande, explicite et sans cascade
# ADR  : 0036 (amendement 2), 0043
module Ports
  module Assessment
    module LearningDataEraserPort
      # Efface ses sessions d'exercice, leurs réponses, ses badges et ses lacunes ; aucune ligne d'un autre élève n'est
      # effacée. Appelé dans la transaction de l'anonymisation. → true
      def erase_for(student_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #erase_for"
      end
    end
  end
end

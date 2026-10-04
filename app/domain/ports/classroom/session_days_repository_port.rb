# 🧠 DOMAINE · Ports::Classroom::SessionDaysRepositoryPort
# Rôle : contrat des jours de séance d'un enseignant dans une classe qu'il déclare (classroom_session_days)
# ADR  : 0072
module Ports
  module Classroom
    module SessionDaysRepositoryPort
      # → Entities::Classroom::SessionDays ; vide si non renseigné (aucune ligne).
      def for(teacher_id:, classroom_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #for"
      end

      # Remplace tous les jours de l'enseignant dans la classe, en une transaction ; [] revient à « non renseigné ».
      # Ne touche à aucune assignation. Un jour hors de 1..6 lève ArgumentError, rien n'est écrit. → true
      def replace(teacher_id:, classroom_id:, weekdays:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #replace"
      end
    end
  end
end

# 🧠 DOMAINE · Entities::Classroom::FollowUpPriority
# Rôle : « À suivre » de l'accueil enseignant : une classe d'élèves qui a du retard ou un exercice en cours ; la plus urgente d'abord
# UDR  : accueil-enseignant-actions (§3.1)
module Entities
  module Classroom
    module FollowUpPriority
      # Une classe sans élève n'a personne à relancer : jamais à suivre.
      def self.to_follow?(students:, late_students:, active_assignments:)
        students.positive? && (late_students.positive? || active_assignments.positive?)
      end

      # Clé de tri : élèves en retard, décroissant ; puis exercices en cours, décroissant ; puis position (l'ordre des classes).
      def self.rank(late_students:, active_assignments:, position:)
        [ -late_students, -active_assignments, position ]
      end
    end
  end
end

# 🧠 DOMAINE · Entities::Classroom::AdoptionVerdict
# Rôle : désigne le goulot d'acquisition des classes (enseignants, établissements, classes cochées, élèves) à partir des compteurs de l'entonnoir
# ADR  : 0138, 0024
module Entities
  module Classroom
    module AdoptionVerdict
      # Seuils par défaut (PRD acquisition-classes §3.2), modifiables par le porteur après la première lecture.
      MIN_TEACHERS = 10
      MIN_SCHOOLS_WITH_INTERACTION = 10
      MAX_BLOCKED_PERCENT = 30
      MIN_TICKED_PERCENT = 50
      MIN_POPULATED_PERCENT = 50
      MIN_MEDIAN_STUDENTS = 10

      # Les étapes se lisent dans l'ordre : le premier goulot atteint est retenu.
      # :teachers (1) · :awareness (4) · :no_open_class (2a) · :no_class_ticked (2a′) · :code_not_shared (2b) · :code_ignored (3) · :none
      def self.call(e1:, blocked:, e2:, e3:, e4:, empty_with_assignment:, empty_without_assignment:, crm_schools_with_interaction:,
                    median_students_per_populated_class:, **)
        return (crm_schools_with_interaction < MIN_SCHOOLS_WITH_INTERACTION ? :awareness : :teachers) if e1 < MIN_TEACHERS
        return :no_open_class if blocked * 100 >= e1 * MAX_BLOCKED_PERCENT
        return :no_class_ticked if e3 * 100 < e2 * MIN_TICKED_PERCENT
        return empty_class_bottleneck(empty_with_assignment, empty_without_assignment) if e4 * 100 < e3 * MIN_POPULATED_PERCENT

        median_students_per_populated_class.to_f < MIN_MEDIAN_STUDENTS ? :code_ignored : :none
      end

      # Parmi les enseignants à classe vide : plus de la moitié ont donné un devoir (élèves absents) → 3, sinon le code n'est pas parti → 2b.
      def self.empty_class_bottleneck(with_assignment, without_assignment)
        with_assignment * 2 > with_assignment + without_assignment ? :code_ignored : :code_not_shared
      end
      private_class_method :empty_class_bottleneck
    end
  end
end

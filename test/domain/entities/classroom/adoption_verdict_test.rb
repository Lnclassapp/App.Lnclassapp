require "test_helper"

module Entities
  module Classroom
    # Chantier acquisition-classes, lot A, PRD §3.2 : la règle qui désigne le goulot, un cas par branche.
    class AdoptionVerdictTest < ActiveSupport::TestCase
      # Un entonnoir sain : 20 enseignants, tous avec classe, tous peuplés, 12 élèves par classe, 12 écoles jointes.
      HEALTHY = { e1: 20, blocked: 0, e2: 20, e3: 20, e4: 20, e5: 10, e6: 10, empty_with_assignment: 0, empty_without_assignment: 0,
                  crm_schools_with_interaction: 12, median_students_per_populated_class: 12 }.freeze

      def verdict(**changes) = AdoptionVerdict.call(**HEALTHY, **changes)

      test "moins de 10 enseignants : goulot 1" do
        assert_equal :teachers, verdict(e1: 9, blocked: 0, e2: 9, e3: 9, e4: 9)
      end

      test "moins de 10 enseignants et moins de 10 écoles avec un échange : goulot 4" do
        assert_equal :awareness, verdict(e1: 9, crm_schools_with_interaction: 9)
      end

      test "10 enseignants pile ne sont pas un goulot 1" do
        assert_equal :none, verdict(e1: 10, e2: 10, e3: 10, e4: 10)
      end

      test "10 écoles avec un échange pile ne sont pas un goulot 4" do
        assert_equal :teachers, verdict(e1: 9, crm_schools_with_interaction: 10)
      end

      test "aucun enseignant : goulot 4 quand le CRM est vide" do
        assert_equal :awareness, verdict(e1: 0, e2: 0, e3: 0, e4: 0, crm_schools_with_interaction: 0)
      end

      test "30 % de bloqués : goulot 2a" do
        assert_equal :no_open_class, verdict(blocked: 6, e2: 14, e3: 14, e4: 14)
      end

      test "29 % de bloqués ne suffisent pas" do
        assert_equal :none, verdict(e1: 100, blocked: 29, e2: 71, e3: 71, e4: 71)
      end

      test "moins de la moitié des E2 cochent une classe : goulot 2a'" do
        assert_equal :no_class_ticked, verdict(e3: 9, e4: 9)
      end

      test "la moitié pile des E2 qui cochent n'est pas un goulot" do
        assert_equal :none, verdict(e3: 10, e4: 10)
      end

      test "moins de la moitié des E3 ont une classe peuplée, sans devoir donné : goulot 2b" do
        assert_equal :code_not_shared, verdict(e4: 9, empty_with_assignment: 0, empty_without_assignment: 11)
      end

      test "moins de la moitié des E3 ont une classe peuplée, la majorité des vides ayant un devoir : goulot 3" do
        assert_equal :code_ignored, verdict(e4: 9, empty_with_assignment: 6, empty_without_assignment: 5)
      end

      test "la moitié des vides avec devoir pile : goulot 2b" do
        assert_equal :code_not_shared, verdict(e4: 9, empty_with_assignment: 5, empty_without_assignment: 5)
      end

      test "médiane sous 10 élèves : goulot 3" do
        assert_equal :code_ignored, verdict(median_students_per_populated_class: 9.5)
      end

      test "médiane de 10 élèves pile : aucun goulot" do
        assert_equal :none, verdict(median_students_per_populated_class: 10)
      end

      test "pas de classe peuplée : la médiane absente compte comme zéro" do
        assert_equal :code_ignored, verdict(median_students_per_populated_class: nil)
      end

      test "l'ordre des étapes : le premier goulot atteint gagne" do
        assert_equal :no_open_class, verdict(blocked: 10, e2: 10, e3: 1, e4: 0, median_students_per_populated_class: 1)
      end
    end
  end
end

require "test_helper"

module Dtos
  module Classroom
    # ADR-0098, UDR-0110 : la modale « Modifier la classe » n'envoie que la fin du nom et le plafond.
    class ClassroomSettingsInputTest < ActiveSupport::TestCase
      def input(**overrides) = ClassroomSettingsInput.new(suffix: "A", max_students: "95", **overrides)

      test "une saisie complète est valide, plafond converti en entier, suffixe compacté" do
        form = input(suffix: "  Excellence   2 ")

        assert form.valid?
        assert_equal [ "Excellence 2", 95 ], [ form.suffix, form.max_students ]
      end

      test "exige la fin du nom" do
        [ "", "   ", nil ].each do |suffix|
          form = input(suffix:)

          assert_not form.valid?, suffix.inspect
          assert form.errors.of_kind?(:suffix, :blank)
        end
      end

      test "le plafond est un entier entre 1 et 150" do
        assert input(max_students: 1).valid?
        assert input(max_students: 150).valid?
        [ 0, 151, "", "abc", nil ].each do |max_students|
          assert_not input(max_students:).valid?, max_students.inspect
        end
      end
    end
  end
end

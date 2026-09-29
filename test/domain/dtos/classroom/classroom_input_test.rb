require "test_helper"

module Dtos
  module Classroom
    class ClassroomInputTest < ActiveSupport::TestCase
      def input(**overrides)
        ClassroomInput.new(school_public_id: "abcdefghijkmno", level_slug: "tle", series_slug: "d", name: "Tle D 7",
                           max_students: "60", **overrides)
      end

      test "une saisie complète est valide, plafond converti en entier" do
        form = input

        assert form.valid?
        assert_equal [ "abcdefghijkmno", "tle", "d", "Tle D 7", 60 ],
                     [ form.school_public_id, form.level_slug, form.series_slug, form.name, form.max_students ]
      end

      test "le plafond vaut 80 par défaut" do
        assert_equal 80, ClassroomInput.new.max_students
      end

      test "normalise les espaces du nom sans changer la casse ; une série vide devient nil" do
        form = input(name: "  tle   d 7 ", series_slug: " ", level_slug: " tle ")

        assert_equal "tle d 7", form.name
        assert_equal "tle", form.level_slug
        assert_nil form.series_slug
      end

      test "exige l'établissement, le niveau et le nom" do
        form = input(school_public_id: "", level_slug: "", name: "   ")

        assert_not form.valid?
        assert form.errors.of_kind?(:school_public_id, :blank)
        assert form.errors.of_kind?(:level_slug, :blank)
        assert form.errors.of_kind?(:name, :blank)
        assert_nil form.level_slug
      end

      test "limite le nom à 15 caractères" do
        assert input(name: "a" * 15).valid?
        form = input(name: "a" * 16)

        assert_not form.valid?
        assert form.errors.of_kind?(:name, :too_long)
      end

      test "le plafond est un entier entre 1 et 150" do
        assert input(max_students: 1).valid?
        assert input(max_students: 150).valid?
        [ 0, 151, "", "douze" ].each do |max_students|
          assert_not input(max_students:).valid?, max_students.inspect
        end
      end

      test "to_h donne les attributs de la classe" do
        assert_equal({ name: "Tle D 7", max_students: 60 }, input.to_h)
      end
    end
  end
end

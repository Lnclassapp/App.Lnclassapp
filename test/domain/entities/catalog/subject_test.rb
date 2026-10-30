require "test_helper"

module Entities
  module Catalog
    # ADR-XXXX sujets-de-devoir §4 : un sujet de devoir d'une leçon (titre, notions mobilisées, ordre).
    class SubjectTest < ActiveSupport::TestCase
      def subject(**attributes)
        Subject.new(course_id: 1, position: 1, title: "Sujet 1 · Thalès", notions: "Thalès, proportionnalité", **attributes)
      end

      test "un sujet complet est valide" do
        assert_predicate subject, :valid?
      end

      test "le titre est obligatoire, au plus 200 caractères, et nettoyé" do
        assert_not subject(title: " ").valid?
        assert_not subject(title: "a" * 201).valid?
        assert_predicate subject(title: "a" * 200), :valid?
        assert_equal "Sujet 1 · Thalès", subject(title: "  Sujet 1 ·   Thalès ").title
      end

      test "les notions mobilisées font de 1 à 600 caractères" do
        assert_not subject(notions: "").valid?
        assert_not subject(notions: "a" * 601).valid?
        assert_predicate subject(notions: "a" * 600), :valid?
      end

      test "le cours et la position sont obligatoires, la position est positive" do
        assert_not subject(course_id: nil).valid?
        assert_not subject(position: 0).valid?
        assert_not subject(position: nil).valid?
      end

      test "le texte est gardé tel quel, sans HTML interprété" do
        assert_equal "<script>x</script>", subject(notions: "<script>x</script>").notions
      end
    end
  end
end

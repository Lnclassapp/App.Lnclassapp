require "test_helper"

# ADR-XXXX §4.1 : le gabarit d'une notion, une règle par test.
module Entities
  module Catalog
    class NotionSheetTest < ActiveSupport::TestCase
      def raw(**changes) = revision_notion("Notion").except("name", "exercise", "figure").merge(changes.stringify_keys)

      test "une notion de la fabrique n'a aucune erreur" do
        assert_empty NotionSheet.errors_for(raw)
      end

      test "remember et pitfall : non vides et 1 200 caractères au plus" do
        assert_equal [ [ "remember", "blank" ] ], NotionSheet.errors_for(raw(remember: "  "))
        assert_equal [ [ "pitfall", "blank" ] ], NotionSheet.errors_for(raw(pitfall: nil))
        assert_equal [ [ "remember", "too_long" ] ], NotionSheet.errors_for(raw(remember: "a" * 1_201))
        assert_empty NotionSheet.errors_for(raw(pitfall: "a" * 1_200))
      end

      test "method : 2 à 8 étapes, 300 caractères au plus chacune" do
        one = [ "Une seule." ]
        assert_includes NotionSheet.errors_for(raw(method: one, example: { "statement" => "x", "steps" => one })), [ "method", "invalid_count" ]
        nine = Array.new(9) { "Étape #{it}" }
        assert_includes NotionSheet.errors_for(raw(method: nine, example: { "statement" => "x", "steps" => nine })), [ "method", "invalid_count" ]
        long = [ "a" * 301, "b" ]
        assert_equal [ [ "method[0]", "too_long" ] ], NotionSheet.errors_for(raw(method: long, example: { "statement" => "x", "steps" => %w[x y] }))
      end

      test "example.steps doit compter autant d'étapes que method" do
        errors = NotionSheet.errors_for(raw(example: { "statement" => "Simplifier.", "steps" => [ "Une seule étape." ] }))

        assert_equal [ [ "example.steps", "example_steps_mismatch" ] ], errors
      end

      test "un exemple sans énoncé est refusé" do
        errors = NotionSheet.errors_for(raw(example: { "statement" => "", "steps" => revision_notion("N")["example"]["steps"] }))

        assert_equal [ [ "example.statement", "blank" ] ], errors
      end

      test "une valeur qui n'est pas du texte est refusée sans lever" do
        assert_equal [ [ "remember", "blank" ] ], NotionSheet.errors_for(raw(remember: 12))
      end

      test "from_raw lit la fiche, avec la clé de la figure citée" do
        sheet = NotionSheet.from_raw(raw.merge("figure" => "triangle-thales"))

        assert_equal 3, sheet.method_steps.size
        assert_equal "Simplifier $\\sqrt{72}$.", sheet.example_statement
        assert_equal "triangle-thales", sheet.figure_key
      end
    end
  end
end

require "test_helper"

# ADR-0116 §4.1 : le schéma v3 accepte la leçon de la fabrique et refuse chaque borne qu'il porte.
module Schemas
  class CourseTreeV3SchemaTest < ActiveSupport::TestCase
    SCHEMA = JSONSchemer.schema(Rails.root.join("config/schemas/lnclass.course-tree.v3.json").read)

    def valid?(document) = SCHEMA.valid?(document)
    def course(document) = document["courses"].first

    def with_course(**changes) = revision_sheet_document(**changes)

    test "la leçon de la fabrique est acceptée" do
      assert_empty SCHEMA.validate(revision_sheet_document).map { it["error"] }
    end

    test "une version autre que 3 est refusée" do
      refute valid?(revision_sheet_document.merge("version" => 2))
    end

    test "une clé inconnue est refusée à chaque niveau" do
      refute valid?(with_course(extra: 1))
      document = revision_sheet_document
      course(document)["notions"].first["extra"] = 1
      refute valid?(document)
    end

    test "theme : blue, teal ou burgundy seulement ; absent admis" do
      assert valid?(with_course(theme: "teal"))
      refute valid?(with_course(theme: "pink"))
      document = revision_sheet_document
      course(document).delete("theme")
      assert valid?(document)
    end

    test "notions : 1 à 12" do
      refute valid?(with_course(notions: []))
      refute valid?(with_course(notions: Array.new(13) { revision_notion("N#{it}") }))
    end

    test "exercises : le nombre est compté par l'adaptateur (lesson_exercise_count), pas par le schéma" do
      assert valid?(with_course(exercises: Array.new(3) { revision_exercise("P") }))
      assert valid?(with_course(exercises: Array.new(5) { revision_exercise("P") }))
      refute valid?(with_course(exercises: "P"))
    end

    test "exercise d'une notion : absent, null ou liste passent au schéma (essential_exercise_count) ; un objet est vérifié" do
      assert valid?(with_course(notions: [ revision_notion("N").except("exercise") ]))
      assert valid?(with_course(notions: [ revision_notion("N").merge("exercise" => nil) ]))
      assert valid?(with_course(notions: [ revision_notion("N").merge("exercise" => []) ]))
      refute valid?(with_course(notions: [ revision_notion("N").merge("exercise" => { "title" => "T" }) ]))
    end

    test "method : 2 à 8 étapes de 300 caractères au plus" do
      notion = revision_notion("N")
      refute valid?(with_course(notions: [ notion.merge("method" => [ "seule" ]) ]))
      refute valid?(with_course(notions: [ notion.merge("method" => Array.new(9, "étape")) ]))
      refute valid?(with_course(notions: [ notion.merge("method" => [ "a" * 301, "b" ]) ]))
    end

    test "remember et pitfall : 1 200 caractères au plus, non vides" do
      notion = revision_notion("N")
      refute valid?(with_course(notions: [ notion.merge("remember" => "a" * 1_201) ]))
      refute valid?(with_course(notions: [ notion.merge("pitfall" => "") ]))
    end

    test "questions : le nombre et la correction sont vérifiés par l'adaptateur (too_few_questions, invalid_count, blank, too_short, too_long)" do
      exercise = revision_exercise("E")
      assert valid?(with_course(exercises: Array.new(4) { exercise.merge("questions" => exercise["questions"].first(4)) }))
      assert valid?(with_course(exercises: Array.new(4) { exercise.merge("questions" => Array.new(31) { revision_question }) }))
      assert valid?(with_course(exercises: Array.new(4) { exercise.except("questions") }))
      no_explanation = exercise["questions"].map { it.except("explanation") }
      assert valid?(with_course(exercises: Array.new(4) { exercise.merge("questions" => no_explanation) }))
      short = exercise["questions"].map { it.merge("explanation" => "Trop court.") }
      assert valid?(with_course(exercises: Array.new(4) { exercise.merge("questions" => short) }))
      refute valid?(with_course(exercises: Array.new(4) { exercise.merge("questions" => exercise["questions"].map { it.merge("explanation" => 3) }) }))
    end

    test "figures : 12 au plus ; la forme seulement, le reste est jugé par l'adaptateur (figure_invalid)" do
      refute valid?(with_course(figures: Array.new(13) { revision_figure(key: "f#{it}") }))
      refute valid?(with_course(figures: [ revision_figure.except("params") ]))
      refute valid?(with_course(figures: [ revision_figure.merge("params" => "x") ]))
      refute valid?(with_course(figures: [ revision_figure.merge("extra" => 1) ]))
      assert valid?(with_course(figures: [ revision_figure.merge("kind" => "hologram") ]))
      assert valid?(with_course(figures: [ revision_figure.merge("description" => "courte") ]))
      far = revision_figure.merge("params" => { "points" => [ { "id" => "A", "x" => 99, "y" => 0 } ] })
      assert valid?(with_course(figures: [ far ]))
    end

    test "figure citée : une chaîne ou null" do
      assert valid?(with_course(notions: [ revision_notion("N", figure: nil) ]))
      refute valid?(with_course(notions: [ revision_notion("N").merge("figure" => 3) ]))
    end
  end
end

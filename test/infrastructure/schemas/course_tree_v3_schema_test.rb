require "test_helper"

# ADR-XXXX §4.1 : le schéma v3 accepte la leçon de la fabrique et refuse chaque borne qu'il porte.
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

    test "exercises : exactement quatre" do
      refute valid?(with_course(exercises: Array.new(3) { revision_exercise("P") }))
      refute valid?(with_course(exercises: Array.new(5) { revision_exercise("P") }))
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

    test "questions : 5 à 30 par exercice, explication de 20 à 2 000 caractères obligatoire" do
      exercise = revision_exercise("E")
      refute valid?(with_course(exercises: Array.new(4) { exercise.merge("questions" => exercise["questions"].first(4)) }))
      refute valid?(with_course(exercises: Array.new(4) { exercise.merge("questions" => Array.new(31) { revision_question }) }))
      no_explanation = exercise["questions"].map { it.except("explanation") }
      refute valid?(with_course(exercises: Array.new(4) { exercise.merge("questions" => no_explanation) }))
      short = exercise["questions"].map { it.merge("explanation" => "Trop court.") }
      refute valid?(with_course(exercises: Array.new(4) { exercise.merge("questions" => short) }))
    end

    test "figures : 12 au plus, sorte de la liste fermée, description de 150 à 600 caractères, contrôles 4 au plus" do
      refute valid?(with_course(figures: Array.new(13) { revision_figure(key: "f#{it}") }))
      refute valid?(with_course(figures: [ revision_figure.merge("kind" => "hologram") ]))
      refute valid?(with_course(figures: [ revision_figure.merge("description" => "courte") ]))
      refute valid?(with_course(figures: [ revision_figure.merge("description" => "a" * 601) ]))
      control = { "param" => "a", "min" => 1, "max" => 9, "step" => 1, "label" => "a" }
      refute valid?(with_course(figures: [ revision_figure.merge("controls" => Array.new(5) { control }) ]))
    end

    test "figures : paramètres bornés par la sorte" do
      far = revision_figure.merge("params" => { "points" => [ { "id" => "A", "x" => 99, "y" => 0 } ] })
      refute valid?(with_course(figures: [ far ]))
      many = revision_figure.merge("params" => { "points" => Array.new(13) { { "id" => "P#{it}", "x" => 0, "y" => 0 } } })
      refute valid?(with_course(figures: [ many ]))
      unknown = revision_figure.merge("params" => { "script" => "x" })
      refute valid?(with_course(figures: [ unknown ]))
      refute valid?(with_course(figures: [ revision_figure.merge("kind" => "stat_chart", "params" => { "chart" => "radar" }) ]))
    end

    test "figure citée : une chaîne ou null" do
      assert valid?(with_course(notions: [ revision_notion("N", figure: nil) ]))
      refute valid?(with_course(notions: [ revision_notion("N").merge("figure" => 3) ]))
    end
  end
end

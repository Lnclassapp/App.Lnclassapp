require "test_helper"
require_relative "../../../support/domain/taxonomy_fixture"

module Entities
  module Catalog
    class ContentNodeTest < ActiveSupport::TestCase
      setup { @lookup = TaxonomyFixture.lookup }

      def answers(*flags) = flags.map { |correct| { "content" => "p", "is_correct" => correct } }

      def question(type = "single_choice", answers: answers(true, false))
        { "content" => "Question ?", "question_type" => type, "answers" => answers }
      end

      def exercise(**overrides)
        { "title" => "Mitose", "exercise_type" => "fixation", "questions" => [ question ] }.merge(overrides)
      end

      def course(**overrides)
        { "name" => "Génétique", "level_name" => "Tle", "series_name" => "D", "material_name" => "Physique Chimie",
          "status" => "publié", "essentials" => [ { "name" => "ADN", "exercises" => [ exercise ] } ] }.merge(overrides)
      end

      def codes(errors) = errors.map { [ it.path, it.code ] }

      test "un cours complet de l'ancienne application est valide, statut ignoré" do
        assert_empty ContentNode.validate_course(course, path: "courses[0]", lookup: @lookup)
        assert_empty ContentNode.validate_course(course("series_name" => nil, "level_name" => "3ème"), path: "c", lookup: @lookup)
      end

      test "référentiel : niveau, matière, série inconnus ou non liés" do
        errors = ContentNode.validate_course(course("level_name" => "Terminale", "material_name" => "Chimie",
                                                    "series_name" => "B"), path: "courses[3]", lookup: @lookup)

        assert_equal [ [ "courses[3].level_name", "unknown_level" ], [ "courses[3].material_name", "unknown_material" ],
                       [ "courses[3].series_name", "unknown_series" ] ], codes(errors)
        assert_equal({ value: "Terminale" }, errors.first.params)
        assert_equal [ [ "c.series_name", "series_not_allowed" ] ],
                     codes(ContentNode.validate_course(course("series_name" => "A"), path: "c", lookup: @lookup))
        assert_equal [ [ "c.level_name", "unknown_level" ] ],
                     codes(ContentNode.validate_course(course("level_name" => nil, "series_name" => "A"), path: "c", lookup: @lookup))
      end

      test "noms présents et bornés, erreurs localisées jusqu'aux propositions" do
        tree = course("name" => " ", "subtitle" => "a" * 151,
                      "essentials" => [ { "name" => "ADN", "exercises" => [ exercise, exercise("title" => "a" * 151) ] } ])
        errors = ContentNode.validate_course(tree, path: "courses[3]", lookup: @lookup)

        assert_equal [ [ "courses[3].name", "blank" ], [ "courses[3].subtitle", "too_long" ],
                       [ "courses[3].essentials[0].exercises[1].title", "too_long" ] ], codes(errors)
        assert_equal({ max: 150 }, errors.last.params)
      end

      test "une fiche : nom et exercices" do
        errors = ContentNode.validate_essential({ "name" => nil, "exercises" => [ exercise("exercise_type" => "examen") ] }, path: "essentials[2]")

        assert_equal [ [ "essentials[2].name", "blank" ], [ "essentials[2].exercises[0].exercise_type", "invalid_value" ] ], codes(errors)
      end

      test "un exercice : au moins une question, cohérence de l'ADR-0039" do
        assert_empty ContentNode.validate_exercise(exercise("questions" => [ question("true_false"), question("multiple_correct_2", answers: answers(true, true, false)) ]), path: "e")
        assert_equal [ [ "e.questions", "blank" ] ], codes(ContentNode.validate_exercise(exercise("questions" => nil), path: "e"))

        errors = ContentNode.validate_exercise(exercise("questions" => [ question("true_false", answers: answers(true, false, false)),
                                                                         question("essay"), { "question_type" => "single_choice", "answers" => [ { "content" => "", "correct" => true }, { "content" => "b", "correct" => false } ] } ]),
                                               path: "exercises[1]")

        assert_equal [ [ "exercises[1].questions[0].answers", "question_structure" ], [ "exercises[1].questions[1].question_type", "invalid_value" ],
                       [ "exercises[1].questions[2].content", "blank" ], [ "exercises[1].questions[2].answers[0].content", "blank" ] ], codes(errors)
        assert_equal({ rule: :true_false_needs_two_answers }, errors.first.params)
      end

      test "un nœud qui n'est pas un objet est une erreur de schéma" do
        assert_equal [ [ "c", "schema" ] ], codes(ContentNode.validate_course("texte", path: "c", lookup: @lookup))
        assert_equal [ [ "f", "schema" ] ], codes(ContentNode.validate_essential(nil, path: "f"))
        assert_equal [ [ "e", "schema" ] ], codes(ContentNode.validate_exercise([], path: "e"))
        assert_equal [ [ "e.questions[0]", "schema" ], [ "e.questions[1].answers", "schema" ] ],
                     codes(ContentNode.validate_exercise(exercise("questions" => [ "q", question(answers: [ "a" ]) ]), path: "e"))
      end
    end
  end
end

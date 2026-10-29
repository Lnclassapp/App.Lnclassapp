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
        assert_equal [ [ "e", "schema" ] ], codes(ContentNode.validate_exercise([], path: "e"))
        assert_equal [ [ "e.questions[0]", "schema" ], [ "e.questions[1].answers", "schema" ] ],
                     codes(ContentNode.validate_exercise(exercise("questions" => [ "q", question(answers: [ "a" ]) ]), path: "e"))
      end
    end
  end
end

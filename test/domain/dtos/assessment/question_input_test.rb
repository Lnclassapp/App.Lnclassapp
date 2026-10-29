require "test_helper"

# ADR-0115 : la saisie d'une question porte aussi ses points, son unité, son début de phrase et sa grille ; modifier un exercice
# importé ne les remet jamais aux valeurs par défaut.
module Dtos
  module Assessment
    class QuestionInputTest < ActiveSupport::TestCase
      def entity(**attributes)
        Entities::Assessment::Question.new(id: 1, position: 1, content: "Explique.", explanation: "Corrigé", question_type: "written", answers: [],
                                           **attributes)
      end

      test "defaults: 1 point, no unit, no starter, no criteria" do
        built = QuestionInput.from_params(content: "Q", question_type: "true_false").to_entity(position: 1)

        assert_equal [ BigDecimal("1"), nil, nil, [] ], [ built.points, built.unit, built.starter, built.criteria ]
      end

      test "a question read back is written again with the same points, unit, starter and criteria" do
        original = entity(points: BigDecimal("3.5"), unit: "cm", starter: "Car…", criteria: [ "Je cite", "Je compare" ])

        again = QuestionInput.from_question(original).to_entity(position: 1)

        assert_equal [ BigDecimal("3.5"), "cm", "Car…", [ "Je cite", "Je compare" ] ], [ again.points, again.unit, again.starter, again.criteria ]
      end

      test "params are read: a decimal comma, blank values as null, blank criteria removed" do
        built = QuestionInput.from_params(content: "Q", question_type: "written", points: "2,5", unit: " ", starter: "",
                                          criteria: [ "Un", "", "  ", "Deux" ]).to_entity(position: 1)

        assert_equal [ BigDecimal("2.5"), nil, nil, [ "Un", "Deux" ] ], [ built.points, built.unit, built.starter, built.criteria ]
      end

      test "points that are not a number are invalid" do
        input = QuestionInput.from_params(content: "Q", question_type: "written", points: "beaucoup")

        assert_not input.valid?
        assert_includes input.errors.attribute_names, :points
      end

      test "points out of range are left to the question structure, which names the rule" do
        built = QuestionInput.from_params(content: "Q", question_type: "written", points: "21", explanation: "x").to_entity(position: 1)

        assert_includes built.structure_errors, :points_out_of_range
      end
    end
  end
end

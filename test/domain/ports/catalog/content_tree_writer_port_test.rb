require "test_helper"

module Ports
  module Catalog
    # Les nœuds que lisent les imports : une question d'un fichier d'import validé devient un QuestionNode.
    class ContentTreeWriterPortTest < ActiveSupport::TestCase
      QuestionNode = ContentTreeWriterPort::QuestionNode

      def import(**changes) = { "content" => " Question ? ", "question_type" => "single_choice", "answers" => [] }.merge(changes.stringify_keys)

      test "a question of the legacy format reads is_correct on the choices, and trims every text" do
        node = QuestionNode.from_import(import(answers: [ { "content" => " a ", "is_correct" => true }, { "content" => "b", "is_correct" => false } ],
                                               explanation: " Parce que. "), position: 3)

        assert_equal [ 3, "Question ?", "Parce que." ], [ node.position, node.content, node.explanation ]
        assert_equal [ [ 1, "a", true ], [ 2, "b", false ] ], node.answers.map { [ it.position, it.content, it.correct ] }
      end

      test "a question of the schema format reads correct, which wins over is_correct" do
        node = QuestionNode.from_import(import(answers: [ { "content" => "a", "correct" => false, "is_correct" => true }, { "content" => "b" } ]), position: 1)

        assert_equal [ false, false ], node.answers.map(&:correct)
      end

      test "outside the choices every element is correct, and match is the right side of a pair" do
        node = QuestionNode.from_import(import(question_type: "matching", answers: [ { "content" => "a", "match" => " 1 " }, { "content" => "b", "match" => " " } ]), position: 1)

        assert_equal [ true, true ], node.answers.map(&:correct)
        assert_equal [ "1", nil ], node.answers.map(&:match_content)
      end

      test "tolerance, points, image description, unit, starter and criteria are carried, normalised" do
        node = QuestionNode.from_import(import(question_type: "numeric", answers: [ { "content" => "4,5" } ], tolerance: 0.25, points: 2.5,
                                               image: { "description" => "  Un   schéma \n du  cœur " }, unit: " cm ", starter: " Je pense ", criteria: [ " clarté ", " ", "rigueur" ]),
                                        position: 1)

        assert_equal [ BigDecimal("0.25"), BigDecimal("2.5") ], [ node.numeric_tolerance, node.points ]
        assert_equal [ "Un schéma du cœur", "cm", "Je pense", [ "clarté", "rigueur" ] ], [ node.image_description, node.unit, node.starter, node.criteria ]
      end

      test "without those keys the question takes the defaults" do
        node = QuestionNode.from_import(import, position: 1)

        assert_equal [ nil, BigDecimal("1"), nil, nil, nil, [], nil ],
                     [ node.numeric_tolerance, node.points, node.unit, node.starter, node.image_description, node.criteria, node.explanation ]
      end
    end
  end
end

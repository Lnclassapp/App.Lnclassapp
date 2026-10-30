require "test_helper"

# ADR questions à plusieurs cases et indice (§4) : les attributs et le contrat posés par le socle, sans règle de correction par case.
module Entities
  module Assessment
    class BlanksContractTest < ActiveSupport::TestCase
      def answer(blank: nil, **) = Answer.new(id: 1, position: 1, content: "4", correct: true, **(blank ? { blank: } : {}))

      def question(answers, type: "numeric", **)
        Question.new(id: 1, position: 1, content: "Q ___", explanation: nil, question_type: type, answers:, **)
      end

      test "une réponse sans case est celle de la case 0" do
        assert_equal 0, answer.blank
        assert_equal 3, answer(blank: 3).blank
      end

      test "le nombre de cases est la plus haute case plus un, 1 sans réponse" do
        assert_equal 1, question([]).blanks
        assert_equal 1, question([ answer ]).blanks
        assert_equal 2, question([ answer, answer(blank: 1) ]).blanks
        assert_equal 6, question([ answer(blank: 5) ]).blanks
      end

      test "la question porte son indice, absent par défaut" do
        assert_nil question([]).hint
        assert_equal "Pense à Thalès.", question([], hint: "Pense à Thalès.").hint
      end

      test "le verdict par case est un contrat : un type qui ne juge pas case par case lève NotImplementedError" do
        assert_raises(NotImplementedError) { question([ answer ]).blank_results([ "4" ]) }
        assert_raises(NotImplementedError) { question([], type: "poem").blank_results([]) }
      end

      test "un type qui répond à blank_results est appelé avec la question et la réponse" do
        kind = QuestionKinds::Numeric
        kind.define_singleton_method(:blank_results) { |question, response| [ question.blanks, response ] }

        assert_equal [ 1, [ "4" ] ], question([ answer ]).blank_results([ "4" ])
      ensure
        kind.singleton_class.send(:remove_method, :blank_results)
      end

      test "une tentative et une copie ont leurs cases et leurs indices vides par défaut" do
        attempt = QuestionAttempt.new(session_id: 1, question_id: 2, selected_answer_ids: [], correct: true, answered_at: Time.current)
        session = ExerciseSession.new(id: 1, public_id: "x", student_id: 1, exercise_id: 1, status: "started", question_count: 1, answered_count: 0,
                                      correct_count: 0, progress_percent: 0, score_percent: nil, kind: "standard", knowledge_gap_id: nil,
                                      classroom_assignment_id: nil, started_at: Time.current, completed_at: nil)

        assert_equal [ [], [] ], [ attempt.blank_responses, attempt.blank_results ]
        assert_equal [], session.hinted_question_ids
        assert_equal [ 7 ], session.with(hinted_question_ids: [ 7 ]).hinted_question_ids
      end
    end
  end
end

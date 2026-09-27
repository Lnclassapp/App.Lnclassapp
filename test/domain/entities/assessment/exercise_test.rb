require "test_helper"

module Entities
  module Assessment
    class ExerciseTest < ActiveSupport::TestCase
      def question(*flags)
        answers = flags.each_with_index.map { |correct, index| Answer.new(id: index, position: index, content: "p", correct:) }
        Question.new(id: 1, position: 0, content: "?", explanation: nil, question_type: "single_choice", answers:)
      end

      def build(**overrides)
        Exercise.new(title: " Mitose  et méiose ", description: "  Lire  ", essential_id: 1, exercise_type: "fixation",
                     status: "draft", questions: [ question(true, false) ], **overrides)
      end

      test "un exercice complet est valide, titre sans changement de casse" do
        exercise = build

        assert exercise.valid?
        assert_equal "Mitose et méiose", exercise.title
        assert_equal "Lire", exercise.description
        assert_nil build(description: " ").description
        assert_nil build(description: nil).description
      end

      test "exige titre borné, fiche, type et statut connus" do
        assert build(title: nil).invalid?
        assert build(title: "a" * 151).invalid?
        assert build(essential_id: nil).invalid?
        assert build(exercise_type: "examen").invalid?
        assert build(status: "brouillon").invalid?
      end

      test "publiable avec au moins une question, toutes bien construites" do
        assert build.publishable?
        assert_not build(questions: nil).publishable?
        assert_not build(questions: [ question(true, false), question(true, true) ]).publishable?
      end

      test "lisible si publié et parents publiés ; questions verrouillées dès une tentative" do
        assert build(status: "published", parents_published: true).readable_chain_published?
        assert_not build(status: "published", parents_published: false).readable_chain_published?
        assert_not build(parents_published: true).readable_chain_published?
        assert build.questions_locked?(has_attempts: true)
        assert_not build.questions_locked?(has_attempts: false)
      end
    end
  end
end

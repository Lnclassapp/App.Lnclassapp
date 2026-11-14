require "test_helper"

# edition-lecon-equipe, Lot B (ADR-0113 §4.6, amendement du 2026-11-14) : l'équipe corrige à l'écran le texte d'un exercice et la
# bonne réponse de ses questions, même déjà tentées ; questions et propositions ne s'ajoutent ni ne se retirent.
module UseCases
  module Assessment
    class CorrectExerciseTextTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 14, 12)
      Clock = Data.define(:now)
      Answer = Entities::Assessment::Answer
      Question = Entities::Assessment::Question
      Text = CorrectExerciseText::ExerciseText
      QuestionText = CorrectExerciseText::QuestionText
      AnswerText = CorrectExerciseText::AnswerText

      class FakeExercises
        include Ports::Assessment::ExerciseRepositoryPort

        attr_reader :written, :locked

        def initialize(exercise)
          @exercise = exercise
          @written = []
          @locked = []
        end

        def find_by_public_id(public_id:) = (@exercise if @exercise.public_id == public_id)
        def lock(id:) = (@locked << id) && true

        def correct_text(exercise:)
          @written << exercise
          exercise
        end
      end

      class FakeAuditLog
        include Ports::Identity::AuditLogPort

        attr_reader :records

        def initialize = @records = []
        def record(**entry) = (@records << entry) && true
      end

      setup do
        choice = Question.new(id: 1, position: 1, content: "Combien ?", explanation: "Parce que.", question_type: "single_choice",
                              answers: [ Answer.new(id: 11, position: 1, content: "Deux", correct: true, match_content: nil, blank: 0),
                                         Answer.new(id: 12, position: 2, content: "Trois", correct: false, match_content: nil, blank: 0) ])
        numeric = Question.new(id: 2, position: 2, content: "Calcule.", explanation: nil, question_type: "numeric",
                               numeric_tolerance: BigDecimal("0"),
                               answers: [ Answer.new(id: 21, position: 1, content: "4", correct: true, match_content: nil, blank: 0) ])
        @exercise = Entities::Assessment::Exercise.new(
          id: 5, public_id: "ex5", course_id: 1, title: "Exercice", statement: "Sujet.", exercise_type: "fixation",
          status: "published", questions: [ choice, numeric ]
        )
        @exercises = FakeExercises.new(@exercise)
        @audit_log = FakeAuditLog.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def questions(choice_answers: [ AnswerText.new(id: 11, content: "Deux", match_content: nil, correct: false),
                                      AnswerText.new(id: 12, content: "Trois", match_content: nil, correct: true) ])
        [ QuestionText.new(id: 1, content: "Combien vraiment ?", explanation: "Corrigé.", hint: "Compte.", answers: choice_answers),
          QuestionText.new(id: 2, content: "Calcule bien.", explanation: nil, hint: nil,
                           answers: [ AnswerText.new(id: 21, content: "5", match_content: nil, correct: false) ]) ]
      end

      def correct(public_id = "ex5", actor: @team, title: "Exercice corrigé", statement: "Sujet corrigé.", **question_options)
        CorrectExerciseText.new(exercises: @exercises, audit_log: @audit_log, transaction: FakeTransaction.new,
                                policy: Policies::Catalog::ManageContentPolicy.new, clock: Clock.new(NOW))
                           .call(actor:, public_id:, text: Text.new(title:, statement:, hint: "Relis.", questions: questions(**question_options)))
      end

      test "the team corrects the texts and which choice is right; a numeric answer keeps its correct flag; the journal names the keys changed" do
        assert correct.success?

        written = @exercises.written.sole
        assert_equal [ "Exercice corrigé", "Sujet corrigé.", "Relis." ], [ written.title, written.statement, written.hint ]
        choice, numeric = written.questions
        assert_equal [ "Combien vraiment ?", "Corrigé.", "Compte." ], [ choice.content, choice.explanation, choice.hint ]
        assert_equal [ [ 11, false ], [ 12, true ] ], choice.answers.map { [ it.id, it.correct ] }
        assert_equal [ [ 21, "5", true ] ], numeric.answers.map { [ it.id, it.content, it.correct ] }
        assert_equal [ 5 ], @exercises.locked
        assert_equal({ action: "content.corrected", actor_id: 7, at: NOW, subject_type: "Exercise", subject_id: 5,
                       metadata: { public_id: "ex5", answer_key_changed: [ 1 ] } }, @audit_log.records.sole)
      end

      test "a non-team actor is refused, an unknown exercise is not found" do
        assert_equal :forbidden, correct(actor: Entities::Identity::Actor.new(user_id: 8, role: :student)).code
        assert_equal :not_found, correct("inconnu").code
        assert_empty @exercises.written
      end

      test "a question or a choice added, removed or taken from elsewhere is refused: the structure stays with the import" do
        [ [ AnswerText.new(id: 11, content: "Deux", match_content: nil, correct: true) ],
          [ AnswerText.new(id: 11, content: "Deux", match_content: nil, correct: true),
            AnswerText.new(id: 99, content: "Ailleurs", match_content: nil, correct: false) ] ].each do |choice_answers|
          result = correct(choice_answers:)

          assert_equal :invalid, result.code
          assert_equal [ :structure_changed ], result.errors[:base]
        end
        assert_empty @exercises.written
      end

      test "a key that breaks the question type (two right answers on a single choice) is refused with the question number" do
        result = correct(choice_answers: [ AnswerText.new(id: 11, content: "Deux", match_content: nil, correct: true),
                                           AnswerText.new(id: 12, content: "Trois", match_content: nil, correct: true) ])

        assert_equal :invalid, result.code
        assert_includes result.errors.keys, :"questions.1"
        assert_empty @exercises.written
      end

      test "a blank title, a blank statement or a blank question is refused with its field" do
        assert_includes correct(title: " ").errors.keys, :title
        assert_equal [ :blank ], correct(statement: "").errors[:statement]
        blank_choice = [ AnswerText.new(id: 11, content: " ", match_content: nil, correct: true),
                         AnswerText.new(id: 12, content: "Trois", match_content: nil, correct: false) ]
        assert_equal [ :answer_blank ], correct(choice_answers: blank_choice).errors[:"questions.1"]
        assert_empty @exercises.written
      end

      # Revue pannes silencieuses : une règle déjà cassée à l'import ne couvre pas une bonne réponse qu'on retire en plus.
      test "on a question already broken at import, unchecking its last right answer is still refused" do
        broken = Question.new(id: 3, position: 1, content: "Lesquelles ?", explanation: nil, question_type: "multiple_correct_2",
                              answers: [ Answer.new(id: 31, position: 1, content: "A", correct: true, match_content: nil, blank: 0),
                                         Answer.new(id: 32, position: 2, content: "B", correct: false, match_content: nil, blank: 0),
                                         Answer.new(id: 33, position: 3, content: "C", correct: false, match_content: nil, blank: 0) ])
        @exercises = FakeExercises.new(Entities::Assessment::Exercise.new(id: 5, public_id: "ex5", course_id: 1, title: "Exercice", statement: "Sujet.",
                                                                          exercise_type: "fixation", status: "published", questions: [ broken ]))
        answers = ->(first_correct) { [ AnswerText.new(id: 31, content: "A", match_content: nil, correct: first_correct),
                                        AnswerText.new(id: 32, content: "B", match_content: nil, correct: false),
                                        AnswerText.new(id: 33, content: "C", match_content: nil, correct: false) ] }
        save = lambda do |first_correct, content|
          CorrectExerciseText.new(exercises: @exercises, audit_log: @audit_log, transaction: FakeTransaction.new,
                                  policy: Policies::Catalog::ManageContentPolicy.new, clock: Clock.new(NOW))
                             .call(actor: @team, public_id: "ex5", text: Text.new(title: "Exercice", statement: "Sujet.", hint: nil,
                                                                                  questions: [ QuestionText.new(id: 3, content:, explanation: nil, hint: nil, answers: answers.(first_correct)) ]))
        end

        assert save.(true, "Lesquelles vraiment ?").success?, "une coquille passe malgré la règle déjà cassée"
        refused = save.(false, "Lesquelles ?")
        assert_equal :invalid, refused.code
        assert_includes refused.errors[:"questions.1"], :wrong_correct_count
      end
    end
  end
end

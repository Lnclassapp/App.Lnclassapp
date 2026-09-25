require "test_helper"

module UseCases
  module Assessment
    # AS-09, AS-10, AS-11 (ADR-0054) : une tentative par question, corrigée par égalité exacte des ensembles, sans crédit
    # partiel ; la dernière réponse clôt la session dans la même transaction. L'ancienne application acceptait une
    # re-soumission, une proposition d'une autre question et une session abandonnée (C-11).
    class SubmitQuestionAttemptTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      STUDENT = Entities::Identity::Actor.new(user_id: 7, role: :student)
      Answer = Entities::Assessment::Answer
      Question = Entities::Assessment::Question

      # Comme le repository : l'index unique (session, question) refuse une seconde tentative.
      class FakeSessions
        include Ports::Assessment::ExerciseSessionRepositoryPort

        attr_reader :recorded, :locks

        def initialize(session)
          @session = session
          @recorded = []
          @locks = []
        end

        def find_by_public_id(public_id:, lock: false)
          @locks << lock
          @session if @session.public_id == public_id
        end

        def record_attempt(session_id:, question_id:, selected_answer_ids:, correct:, at:)
          return :duplicate if @recorded.any? { it[:question_id] == question_id }

          @recorded << { session_id:, question_id:, selected_answer_ids:, correct:, at: }
          :recorded
        end
      end

      class FakeExercises
        include Ports::Assessment::ExerciseRepositoryPort

        def initialize(exercise)
          @exercise = exercise
        end

        def find(id:) = (@exercise if @exercise.id == id)
      end

      class SpyClose
        attr_reader :calls

        def initialize
          @calls = []
        end

        def call(actor:, session:, essential_id:)
          @calls << [ actor, session.id, essential_id ]
          Shared::Result.success(CloseExerciseSession::Row.new(score_percent: 100, badge_level: :diamond, earned_now: true))
        end
      end

      def question(id, type, answers)
        Question.new(id:, position: id, content: "Q#{id}", explanation: nil, question_type: type,
                     answers: answers.map { |answer_id, correct| Answer.new(id: answer_id, position: answer_id, content: "P", correct:) })
      end

      def exercise
        Entities::Assessment::Exercise.new(
          id: 40, public_id: "ExErCiCe000040", essential_id: 9, title: "Méiose", exercise_type: "fixation", status: "published",
          parents_published: true,
          questions: [ question(1, "true_false", { 11 => true, 12 => false }),
                       question(2, "multiple_correct_2", { 21 => true, 22 => true, 23 => false }) ]
        )
      end

      def session(status: "started", answered_count: 0, student_id: 7)
        Entities::Assessment::ExerciseSession.new(
          id: 5, public_id: "SeSsIoN0000005", student_id:, exercise_id: 40, status:, question_count: 2, answered_count:,
          correct_count: 0, progress_percent: 0, score_percent: nil, kind: "standard", knowledge_gap_id: nil,
          classroom_assignment_id: nil, started_at: NOW - 60, completed_at: nil
        )
      end

      def use_case(stored = session)
        @sessions = FakeSessions.new(stored)
        @close = SpyClose.new
        @transaction = FakeTransaction.new
        SubmitQuestionAttempt.new(sessions: @sessions, exercises: FakeExercises.new(exercise),
                                  policy: Policies::Assessment::SubmitAttemptPolicy.new, close: @close,
                                  transaction: @transaction, clock: Clock.new(NOW))
      end

      def submit(question_id:, answer_ids:, actor: STUDENT, session_public_id: "SeSsIoN0000005", stored: session)
        dto = Dtos::Assessment::AttemptInput.new(session_public_id:, question_id:, answer_ids:)
        use_case(stored).call(actor:, dto:)
      end

      test "une bonne réponse est enregistrée avec les identifiants choisis et son heure, sous verrou, en transaction" do
        result = submit(question_id: 1, answer_ids: [ "11" ])

        assert result.success?
        assert_equal [ "SeSsIoN0000005", 1, true, nil ],
                     [ result.value.session_public_id, result.value.question_id, result.value.correct, result.value.closed ]
        assert_equal [ { session_id: 5, question_id: 1, selected_answer_ids: [ 11 ], correct: true, at: NOW } ], @sessions.recorded
        assert_equal [ true ], @sessions.locks
        assert_equal 1, @transaction.calls
        assert_empty @close.calls
      end

      test "égalité exacte des ensembles, sans crédit partiel ni dépendance à l'ordre" do
        assert submit(question_id: 2, answer_ids: [ 22, 21 ]).value.correct
        assert_not submit(question_id: 2, answer_ids: [ 21, 23 ]).value.correct
        assert_not submit(question_id: 1, answer_ids: [ 12 ]).value.correct
      end

      test "le nombre de propositions cochées doit correspondre au type : sinon :invalid, rien n'est écrit" do
        result = submit(question_id: 2, answer_ids: [ 21 ])

        assert_equal :invalid, result.code
        assert_equal({ answer_ids: [ :wrong_selection ] }, result.errors)
        assert_empty @sessions.recorded
      end

      test "une proposition d'une autre question, ou une question d'un autre exercice : :invalid, rien n'est écrit" do
        assert_equal :invalid, submit(question_id: 1, answer_ids: [ 21 ]).code
        assert_equal :invalid, submit(question_id: 99, answer_ids: [ 11 ]).code
        assert_empty @sessions.recorded
      end

      test "réponse vide : :invalid avec l'erreur du formulaire" do
        result = submit(question_id: 1, answer_ids: [])

        assert_equal :invalid, result.code
        assert_equal [ I18n.t("activemodel.errors.models.dtos/assessment/attempt_input.attributes.answer_ids.blank") ],
                     result.errors[:answer_ids]
      end

      test "doublon : :conflict, la première tentative reste seule" do
        submitter = use_case
        dto = ->(ids) { Dtos::Assessment::AttemptInput.new(session_public_id: "SeSsIoN0000005", question_id: 1, answer_ids: ids) }

        assert submitter.call(actor: STUDENT, dto: dto.call([ 12 ])).success?
        result = submitter.call(actor: STUDENT, dto: dto.call([ 11 ]))

        assert_equal :conflict, result.code
        assert_equal({ base: [ :already_answered ] }, result.errors)
        assert_equal [ [ 12 ] ], @sessions.recorded.map { it[:selected_answer_ids] }
      end

      test "la dernière réponse clôt la session dans la même transaction" do
        result = submit(question_id: 2, answer_ids: [ 21, 22 ], stored: session(answered_count: 1))

        assert_equal [ [ STUDENT, 5, 9 ] ], @close.calls
        assert_equal [ 100, :diamond, true ], result.value.closed.deconstruct
        assert_equal 1, @transaction.calls
      end

      test "une session terminée ou abandonnée refuse toute soumission : :conflict, rien n'est écrit" do
        %w[completed abandoned].each do |status|
          result = submit(question_id: 1, answer_ids: [ 11 ], stored: session(status:))

          assert_equal :conflict, result.code
          assert_equal({ base: [ :session_closed ] }, result.errors)
          assert_empty @sessions.recorded
        end
      end

      test "la session d'un autre élève, ou un autre rôle : :forbidden" do
        assert_equal :forbidden, submit(question_id: 1, answer_ids: [ 11 ], stored: session(student_id: 8)).code
        assert_equal :forbidden, submit(question_id: 1, answer_ids: [ 11 ], actor: Entities::Identity::Actor.new(user_id: 7, role: :teacher)).code
        assert_empty @sessions.recorded
      end

      test "session inconnue : :not_found" do
        assert_equal :not_found, submit(question_id: 1, answer_ids: [ 11 ], session_public_id: "inconnue").code
      end
    end
  end
end

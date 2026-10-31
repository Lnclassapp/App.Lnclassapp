require "test_helper"

module UseCases
  module Assessment
    # CA-14, CA-15 (ADR-0120 questions à plusieurs cases §4) : l'ouverture d'un indice est enregistrée pour l'auteur d'une copie en cours,
    # une seule fois ; question sans indice, question d'un autre exercice, copie rendue ou d'autrui : :not_found, rien d'écrit.
    class OpenHintTest < ActiveSupport::TestCase
      STUDENT = Entities::Identity::Actor.new(user_id: 7, role: :student)
      Question = Entities::Assessment::Question

      class FakeSessions
        include Ports::Assessment::ExerciseSessionRepositoryPort

        attr_reader :hinted, :locks

        def initialize(session)
          @session = session
          @hinted = []
          @locks = []
        end

        def find_by_public_id(public_id:, lock: false)
          @locks << lock
          @session if @session.public_id == public_id
        end

        def record_hint(session_id:, question_id:)
          return :already_opened if @hinted.include?(question_id)

          @hinted << question_id
          :recorded
        end
      end

      class FakeExercises
        include Ports::Assessment::ExerciseRepositoryPort

        def initialize(exercise) = @exercise = exercise
        def find(id:) = (@exercise if @exercise.id == id)
      end

      def question(id, hint: nil) = Question.new(id:, position: id, content: "Q#{id}", explanation: nil, question_type: "numeric", hint:, answers: [])

      def exercise = Entities::Assessment::Exercise.new(
        id: 40, public_id: "ExErCiCe000040", course_id: 3, essential_id: 9, title: "Thalès", exercise_type: "fixation", status: "published",
        parents_published: true, questions: [ question(1), question(2, hint: "Pense au rapport."), question(3, hint: "Le coefficient.") ]
      )

      def session(status: "started", student_id: 7, exercise_id: 40)
        Entities::Assessment::ExerciseSession.new(
          id: 5, public_id: "SeSsIoN0000005", student_id:, exercise_id:, status:, question_count: 3, answered_count: 0,
          correct_count: 0, progress_percent: 0, score_percent: nil, kind: "standard", knowledge_gap_id: nil,
          classroom_assignment_id: nil, started_at: Time.utc(2026, 10, 28), completed_at: nil
        )
      end

      def open_hint(question_id, actor: STUDENT, stored: session, public_id: "SeSsIoN0000005")
        @sessions = FakeSessions.new(stored)
        use_case = OpenHint.new(sessions: @sessions, exercises: FakeExercises.new(exercise), policy: Policies::Assessment::SubmitAttemptPolicy.new,
                                transaction: FakeTransaction.new)
        use_case.call(actor:, public_id:, question_id:)
      end

      test "l'auteur d'une copie en cours ouvre l'indice : enregistré sous verrou, le texte est rendu" do
        result = open_hint(2)

        assert result.success?
        assert_equal [ 2, "Pense au rapport." ], [ result.value.question_id, result.value.hint ]
        assert_equal [ 2 ], @sessions.hinted
        assert_includes @sessions.locks, true
      end

      test "deux ouvertures donnent une seule mention et le même texte" do
        first = open_hint(2)
        sessions = @sessions
        sessions.record_hint(session_id: 5, question_id: 2)

        assert first.success?
        assert_equal [ 2 ], sessions.hinted
      end

      test "une question sans indice : :not_found, rien d'enregistré" do
        result = open_hint(1)

        assert_equal :not_found, result.code
        assert_empty @sessions.hinted
      end

      test "une question d'un autre exercice : :not_found" do
        result = open_hint(999)

        assert_equal :not_found, result.code
        assert_empty @sessions.hinted
      end

      test "un exercice introuvable (supprimé depuis l'ouverture de la copie) : :not_found, rien d'enregistré" do
        result = open_hint(2, stored: session(exercise_id: 41))

        assert_equal :not_found, result.code
        assert_empty @sessions.hinted
      end

      test "une copie rendue : :not_found, rien d'enregistré" do
        result = open_hint(2, stored: session(status: "completed"))

        assert_equal :not_found, result.code
        assert_empty @sessions.hinted
      end

      test "la copie d'un autre élève ou un enseignant : :not_found" do
        assert_equal :not_found, open_hint(2, stored: session(student_id: 8)).code
        assert_equal :not_found, open_hint(2, actor: Entities::Identity::Actor.new(user_id: 7, role: :teacher)).code
        assert_empty @sessions.hinted
      end

      test "une copie introuvable : :not_found" do
        assert_equal :not_found, open_hint(2, public_id: "nope").code
      end
    end
  end
end

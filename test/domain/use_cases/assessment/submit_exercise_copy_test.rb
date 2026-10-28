require "test_helper"

module UseCases
  module Assessment
    # CA-15 à CA-19 (ADR-0112) : la copie est lue, corrigée et notée en un envoi ; une question vide compte faux ; un second
    # envoi n'écrit rien ; une réponse illisible refuse la copie entière. Entrées hostiles : question étrangère, trop de
    # réponses, texte de plus de 200 caractères, octet nul, double envoi, copie d'autrui.
    class SubmitExerciseCopyTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 28, 12)
      Clock = Data.define(:now)
      STUDENT = Entities::Identity::Actor.new(user_id: 7, role: :student)
      Answer = Entities::Assessment::Answer
      Question = Entities::Assessment::Question

      class FakeSessions
        include Ports::Assessment::ExerciseSessionRepositoryPort

        attr_reader :copies, :locks

        def initialize(session)
          @session = session
          @copies = []
          @locks = []
        end

        def find_by_public_id(public_id:, lock: false)
          @locks << lock
          @session if @session.public_id == public_id
        end

        def record_copy(session_id:, attempts:, at:)
          return :duplicate if @copies.any?

          @copies << { session_id:, attempts:, at: }
          :ok
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
          Shared::Result.success(CloseExerciseSession::Row.new(score_percent: 50, badge_level: :bronze, earned_now: true))
        end
      end

      def choice(id, answers) = Question.new(id:, position: id, content: "Q#{id}", explanation: nil, question_type: "true_false",
                                             answers: answers.map { |answer_id, correct| Answer.new(id: answer_id, position: answer_id, content: "P", correct:) })

      def numeric(id) = Question.new(id:, position: id, content: "Q#{id}", explanation: nil, question_type: "numeric",
                                     answers: [ Answer.new(id: id * 10, position: 1, content: "42", correct: true) ])

      def exercise(essential_id: 9, status: "published")
        Entities::Assessment::Exercise.new(
          id: 40, public_id: "ExErCiCe000040", course_id: 3, essential_id:, title: "Thalès", exercise_type: "fixation", status:,
          parents_published: true, questions: [ choice(1, { 11 => true, 12 => false }), numeric(2), choice(3, { 31 => false, 32 => true }) ]
        )
      end

      def session(status: "started", student_id: 7)
        Entities::Assessment::ExerciseSession.new(
          id: 5, public_id: "SeSsIoN0000005", student_id:, exercise_id: 40, status:, question_count: 3, answered_count: 0,
          correct_count: 0, progress_percent: 0, score_percent: nil, kind: "standard", knowledge_gap_id: nil,
          classroom_assignment_id: nil, started_at: NOW - 60, completed_at: nil
        )
      end

      def submit(answers, actor: STUDENT, stored: session, exercise: exercise())
        @sessions = FakeSessions.new(stored)
        @close = SpyClose.new
        @transaction = FakeTransaction.new
        @use_case = SubmitExerciseCopy.new(sessions: @sessions, exercises: FakeExercises.new(exercise),
                                           policy: Policies::Assessment::SubmitAttemptPolicy.new, close: @close,
                                           transaction: @transaction, clock: Clock.new(NOW))
        @use_case.call(actor:, dto: Dtos::Assessment::CopyInput.new(session_public_id: "SeSsIoN0000005", answers:))
      end

      test "CA-15 : une copie juste est corrigée, enregistrée en un envoi sous verrou, puis la session est close dans la même transaction" do
        result = submit({ "1" => { answer_ids: [ "11" ] }, "2" => { response_text: " 42 " }, "3" => { answer_ids: [ "31" ] } })

        assert result.success?
        assert_equal [ false, 50 ], [ result.value.already_closed, result.value.closed.score_percent ]
        copy = @sessions.copies.sole
        assert_equal [ 5, NOW ], [ copy[:session_id], copy[:at] ]
        assert_equal [ [ 1, [ 11 ], nil, true, false ], [ 2, [], "42", true, false ], [ 3, [ 31 ], nil, false, false ] ],
                     copy[:attempts].map { [ it[:question_id], it[:selected_answer_ids], it[:response_text], it[:correct], it[:unanswered] ] }
        assert_equal [ [ STUDENT, 5, 9 ] ], @close.calls
        assert_equal [ true ], @sessions.locks
        assert_equal 1, @transaction.calls
      end

      test "CA-16 : une question absente, ou vide, compte fausse et sans réponse" do
        submit({ "1" => { answer_ids: [ "11" ] }, "2" => { response_text: "   " } })

        attempts = @sessions.copies.sole[:attempts]
        assert_equal [ [ 1, true, false ], [ 2, false, true ], [ 3, false, true ] ], attempts.map { [ it[:question_id], it[:correct], it[:unanswered] ] }
        assert_equal [ [], nil ], [ attempts[1][:selected_answer_ids], attempts[1][:response_text] ]
      end

      test "CA-16 : une copie entièrement vide est acceptée et vaut 0" do
        assert submit({}).success?
        assert_equal [ true, true, true ], @sessions.copies.sole[:attempts].map { it[:unanswered] }
      end

      test "CA-17 : un second envoi de la copie rendue réussit sans rien écrire ni rien clore" do
        result = submit({ "1" => { answer_ids: [ "11" ] } }, stored: session(status: "completed"))

        assert result.success?
        assert_equal [ "SeSsIoN0000005", true, nil ], [ result.value.session_public_id, result.value.already_closed, result.value.closed ]
        assert_empty @sessions.copies
        assert_empty @close.calls
      end

      test "CA-17 : deux envois qui se suivent n'écrivent qu'une copie (doublon refusé par le repository)" do
        submit({ "1" => { answer_ids: [ "11" ] } })
        again = @use_case.call(actor: STUDENT, dto: Dtos::Assessment::CopyInput.new(session_public_id: "SeSsIoN0000005", answers: {}))

        assert_equal :conflict, again.code
        assert_equal 1, @sessions.copies.size
        assert_equal 1, @close.calls.size
      end

      test "CA-18 : une réponse mal formée refuse toute la copie, erreurs rangées par numéro de question, rien n'est écrit" do
        result = submit({ "1" => { answer_ids: [ "11" ] }, "2" => { response_text: "abc" }, "3" => { answer_ids: [ "31", "32" ] } })

        assert_equal :invalid, result.code
        assert_equal [ 2, 3 ], result.errors.keys
        assert_equal({ response_text: [ :not_a_number ] }, result.errors[2])
        assert_equal({ answer_ids: [ :wrong_selection ] }, result.errors[3])
        assert_empty @sessions.copies
        assert_empty @close.calls
      end

      test "menace : un texte de plus de 200 caractères, ou un octet nul, refuse la copie" do
        too_long = submit({ "2" => { response_text: "1" * 201 } })
        null_byte = submit({ "2" => { response_text: "4\u00002" } })

        assert_equal [ :invalid, { response_text: [ :too_long ] } ], [ too_long.code, too_long.errors[2] ]
        assert_equal [ :invalid, { response_text: [ :invalid ] } ], [ null_byte.code, null_byte.errors[2] ]
        assert_empty @sessions.copies
      end

      test "menace : l'identifiant d'une question étrangère à l'exercice refuse la copie" do
        result = submit({ "1" => { answer_ids: [ "11" ] }, "999" => { answer_ids: [ "11" ] } })

        assert_equal [ :invalid, { base: [ :invalid_copy ] } ], [ result.code, result.errors ]
        assert_empty @sessions.copies
      end

      test "menace : plus de réponses que de questions, ou une clé qui n'est pas un nombre, refuse la copie" do
        many = submit(Array.new(4) { |index| [ (index + 1).to_s, { answer_ids: [ "11" ] } ] }.to_h)
        key = submit({ "1; DROP" => { answer_ids: [ "11" ] } })

        assert_equal [ :invalid, :invalid ], [ many.code, key.code ]
        assert_empty @sessions.copies
      end

      test "menace : la copie d'un autre élève, ou un autre rôle, est refusée : :forbidden, même déjà rendue" do
        other = Entities::Identity::Actor.new(user_id: 7, role: :teacher)

        assert_equal :forbidden, submit({}, stored: session(student_id: 8)).code
        assert_equal :forbidden, submit({}, stored: session(student_id: 8, status: "completed")).code
        assert_equal :forbidden, submit({}, actor: other).code
        assert_empty @sessions.copies
      end

      test "une session abandonnée, ou un exercice archivé : :conflict, rien n'est écrit" do
        abandoned = submit({}, stored: session(status: "abandoned"))
        archived = submit({}, exercise: exercise(status: "archived"))

        assert_equal [ :conflict, { base: [ :session_closed ] } ], [ abandoned.code, abandoned.errors ]
        assert_equal [ :conflict, { base: [ :exercise_archived ] } ], [ archived.code, archived.errors ]
        assert_empty @sessions.copies
      end

      test "CA-21 : un exercice de toute la leçon clôt sans notion (essential_id nil)" do
        submit({}, exercise: exercise(essential_id: nil))

        assert_equal [ [ STUDENT, 5, nil ] ], @close.calls
      end

      test "session inconnue : :not_found" do
        sessions = FakeSessions.new(session)
        use_case = SubmitExerciseCopy.new(sessions:, exercises: FakeExercises.new(exercise), policy: Policies::Assessment::SubmitAttemptPolicy.new,
                                          close: SpyClose.new, transaction: FakeTransaction.new, clock: Clock.new(NOW))

        assert_equal :not_found, use_case.call(actor: STUDENT, dto: Dtos::Assessment::CopyInput.new(session_public_id: "inconnue")).code
      end
    end
  end
end

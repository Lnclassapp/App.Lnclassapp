require "test_helper"

module Repositories
  module Assessment
    class ExerciseSessionRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = ExerciseSessionRepository.new
        @student = create_student
        @exercise = create_exercise(questions: 3)
        @at = Time.zone.parse("2026-09-25 10:00")
      end

      def session(**attributes)
        Entities::Assessment::ExerciseSession.new(
          id: nil, public_id: nil, student_id: @student.id, exercise_id: @exercise.id, status: "started", question_count: 3,
          answered_count: 0, correct_count: 0, progress_percent: 0, score_percent: nil, kind: "standard",
          knowledge_gap_id: nil, classroom_assignment_id: nil, started_at: @at, completed_at: nil, **attributes
        )
      end

      test "ouvre une session, la retrouve par public_id, avec ou sans verrou, et comme session ouverte" do
        started = @repository.start(session: session)

        assert_instance_of Entities::Assessment::ExerciseSession, started
        assert_equal [ "started", 3, @at, 14 ], [ started.status, started.question_count, started.started_at, started.public_id.length ]
        assert_equal started, @repository.find_by_public_id(public_id: started.public_id)
        assert_equal started, Orm::ExerciseSession.transaction { @repository.find_by_public_id(public_id: started.public_id, lock: true) }
        assert_equal started, @repository.started_for(student_id: @student.id, exercise_id: @exercise.id)
        assert_nil @repository.find_by_public_id(public_id: "inconnu")
      end

      test "une seconde ouverture renvoie la session déjà ouverte" do
        first = @repository.start(session: session)

        assert_equal first.id, @repository.start(session: session).id
        assert_equal 1, Orm::ExerciseSession.where(student: @student).count
      end

      test "une violation d'unicité sans session ouverte remonte au lieu de renvoyer nil" do
        colliding = Orm::ExerciseSession.new
        colliding.define_singleton_method(:save!) { raise ActiveRecord::RecordNotUnique, "public_id" }

        Orm::ExerciseSession.define_singleton_method(:new) { |*| colliding }
        begin
          assert_raises(ActiveRecord::RecordNotUnique) { @repository.start(session: session) }
        ensure
          Orm::ExerciseSession.singleton_class.remove_method(:new)
        end
      end

      test "record_copy écrit toute la copie d'un coup, avec la contrainte unanswered, et tient les compteurs" do
        started = @repository.start(session: session)
        first, second, third = @exercise.questions.to_a
        attempts = [ { question_id: first.id, selected_answer_ids: [ 1 ], response_text: nil, correct: true, unanswered: false },
                     { question_id: second.id, selected_answer_ids: [], response_text: "-3,5", correct: false, unanswered: false },
                     { question_id: third.id, selected_answer_ids: [], response_text: nil, correct: false, unanswered: true } ]

        assert_equal :ok, @repository.record_copy(session_id: started.id, attempts:, at: @at)

        reloaded = @repository.find_by_public_id(public_id: started.public_id)
        assert_equal [ 3, 1, 100 ], [ reloaded.answered_count, reloaded.correct_count, reloaded.progress_percent ]
        assert_equal [ [ [ 1 ], nil, true ], [ [], "-3,5", false ], [ [], nil, false ] ],
                     @repository.attempts(session_id: started.id).map { [ it.selected_answer_ids, it.response_text, it.correct ] }
        assert_equal [ false, false, true ], Orm::QuestionAttempt.where(exercise_session_id: started.id).order(:id).pluck(:unanswered)
      end

      test "record_copy : une question sans réponse ni marque unanswered est refusée par la base" do
        started = @repository.start(session: session)
        attempt = { question_id: @exercise.questions.first.id, selected_answer_ids: [], response_text: nil, correct: false, unanswered: false }

        assert_raises(ActiveRecord::StatementInvalid) { @repository.record_copy(session_id: started.id, attempts: [ attempt ], at: @at) }
      end

      test "record_copy : une seconde copie n'écrit rien de plus, compteurs compris" do
        started = @repository.start(session: session)
        questions = @exercise.questions.to_a
        copy = questions.map { { question_id: it.id, selected_answer_ids: [], response_text: nil, correct: false, unanswered: true } }
        @repository.record_copy(session_id: started.id, attempts: copy, at: @at)

        assert_equal :ok, @repository.record_copy(session_id: started.id, attempts: copy, at: @at + 1)
        assert_equal 3, Orm::QuestionAttempt.where(exercise_session_id: started.id).count
        assert_equal 3, @repository.find_by_public_id(public_id: started.public_id).answered_count
      end

      test "record_copy : deux tentatives de la même question dans une copie rendent :duplicate, rien n'est écrit" do
        started = @repository.start(session: session)
        attempt = { question_id: @exercise.questions.first.id, selected_answer_ids: [], response_text: nil, correct: false, unanswered: true }

        assert_equal :duplicate, @repository.record_copy(session_id: started.id, attempts: [ attempt, attempt ], at: @at)
        assert_equal 0, Orm::QuestionAttempt.where(exercise_session_id: started.id).count
      end

      # Copie commencée dans l'ancien mode : la tentative existante est gardée, seules les questions sans tentative s'écrivent.
      test "record_copy : une tentative déjà en base est gardée, les autres questions s'écrivent, les compteurs s'additionnent" do
        started = @repository.start(session: session)
        questions = @exercise.questions.order(:position).to_a
        @repository.record_attempt(session_id: started.id, question_id: questions[0].id, selected_answer_ids: [ 1 ], correct: true, at: @at)
        copy = questions.map { { question_id: it.id, selected_answer_ids: [], response_text: nil, correct: false, unanswered: true } }

        assert_equal :ok, @repository.record_copy(session_id: started.id, attempts: copy, at: @at + 1)

        reloaded = @repository.find_by_public_id(public_id: started.public_id)
        assert_equal [ 3, 1, 100 ], [ reloaded.answered_count, reloaded.correct_count, reloaded.progress_percent ]
        assert_equal [ [ questions[0].id, true, false ], [ questions[1].id, false, true ], [ questions[2].id, false, true ] ],
                     Orm::QuestionAttempt.where(exercise_session_id: started.id).order(:question_id).pluck(:question_id, :correct, :unanswered)
      end

      # La contrainte exercise_sessions_question_count_positive interdit déjà 0 : la garde du SQL est une seconde ceinture.
      test "record_copy : le calcul de progression est gardé contre une division par zéro" do
        assert_includes Repositories::Assessment::ExerciseSessionRepository::COPY_COUNTERS_SQL, "NULLIF(question_count, 0)"
      end

      # Menace : deux envois de la même copie passent l'un après l'autre, grâce au verrou de la ligne de la session.
      test "find_by_public_id avec lock lit la session FOR UPDATE, sans lock non" do
        started = @repository.start(session: session)
        statements = []
        collect = ->(*, payload) { statements << payload[:sql] if payload[:sql].match?(/FROM "exercise_sessions"/) }

        ActiveSupport::Notifications.subscribed(collect, "sql.active_record") do
          Orm::ExerciseSession.transaction do
            @repository.find_by_public_id(public_id: started.public_id, lock: true)
            @repository.find_by_public_id(public_id: started.public_id)
          end
        end

        assert_equal [ true, false ], statements.map { it.include?("FOR UPDATE") }
      end

      test "enregistre chaque tentative une fois et tient les compteurs" do
        started = @repository.start(session: session)
        questions = @exercise.questions.to_a

        assert_equal :recorded, @repository.record_attempt(session_id: started.id, question_id: questions[0].id,
                                                           selected_answer_ids: [ 1 ], correct: true, at: @at)
        assert_equal :recorded, @repository.record_attempt(session_id: started.id, question_id: questions[1].id,
                                                           selected_answer_ids: [ 2 ], correct: false, at: @at + 1)
        assert_equal :duplicate, @repository.record_attempt(session_id: started.id, question_id: questions[1].id,
                                                            selected_answer_ids: [ 1 ], correct: true, at: @at + 2)

        reloaded = @repository.find_by_public_id(public_id: started.public_id)

        assert_equal [ 2, 1, 66 ], [ reloaded.answered_count, reloaded.correct_count, reloaded.progress_percent ]
        assert_equal [ [ questions[0].id, [ 1 ], true ], [ questions[1].id, [ 2 ], false ] ],
                     @repository.attempts(session_id: started.id).map { [ it.question_id, it.selected_answer_ids, it.correct ] }
      end

      # ADR-0091 §4.1 : une réponse saisie (trous, nombre) s'enregistre sans proposition.
      test "enregistre une réponse saisie, sans proposition, et la relit" do
        started = @repository.start(session: session)
        question = @exercise.questions.first

        assert_equal :recorded, @repository.record_attempt(session_id: started.id, question_id: question.id, selected_answer_ids: [],
                                                           response_text: "-3,5", correct: true, at: @at)
        assert_equal [ [ [], "-3,5" ] ], @repository.attempts(session_id: started.id).map { [ it.selected_answer_ids, it.response_text ] }
        assert_raises(ActiveRecord::StatementInvalid) do
          Orm::QuestionAttempt.create!(exercise_session_id: started.id, question_id: @exercise.questions.second.id, selected_answer_ids: [],
                                       correct: true, answered_at: @at)
        end
      end

      test "clôture une session ouverte avec son score, une seule fois" do
        started = @repository.start(session: session)

        assert @repository.complete(id: started.id, score_percent: 80, at: @at)
        @repository.complete(id: started.id, score_percent: 10, at: @at + 1)

        completed = @repository.find_by_public_id(public_id: started.public_id)

        assert_equal [ "completed", 80, @at ], [ completed.status, completed.score_percent, completed.completed_at ]
        assert_nil @repository.started_for(student_id: @student.id, exercise_id: @exercise.id)
      end

      # ADR-0115 §4 : les fins des 3 dernières copies terminées de l'élève sur l'exercice, toutes sortes confondues.
      test "recent_completions : les 3 dernières fins, de la plus récente à la plus ancienne" do
        [ 50, 40, 30, 20, 10 ].each { |minutes| create_exercise_session(student: @student, exercise: @exercise, status: "completed", completed_at: @at - minutes.minutes) }

        assert_equal [ @at - 10.minutes, @at - 20.minutes, @at - 30.minutes ],
                     @repository.recent_completions(student_id: @student.id, exercise_id: @exercise.id)
      end

      test "recent_completions : ni les copies abandonnées ou en cours, ni un autre exercice, ni un autre élève" do
        create_exercise_session(student: @student, exercise: @exercise, status: "completed", completed_at: @at)
        create_exercise_session(student: @student, exercise: @exercise, status: "abandoned", completed_at: @at - 3.minutes)
        create_exercise_session(student: @student, exercise: @exercise, status: "started")
        create_exercise_session(student: @student, exercise: create_exercise, status: "completed", completed_at: @at - 1.minute)
        create_exercise_session(student: create_student, exercise: @exercise, status: "completed", completed_at: @at - 2.minutes)

        assert_equal [ @at ], @repository.recent_completions(student_id: @student.id, exercise_id: @exercise.id)
      end

      test "recent_completions : toutes sortes de copies comptent (libre, devoir, remédiation)" do
        gap = create_gap(student: @student, essential: @exercise.essential)
        create_exercise_session(student: @student, exercise: @exercise, status: "completed", completed_at: @at - 20.minutes)
        create_exercise_session(student: @student, exercise: @exercise, status: "completed", completed_at: @at - 10.minutes, gap:)

        create_exercise_session(student: @student, exercise: @exercise, status: "completed", completed_at: @at - 5.minutes,
                                classroom_assignment_id: create_assignment(assignable: @exercise).id)

        assert_equal [ @at - 5.minutes, @at - 10.minutes, @at - 20.minutes ],
                     @repository.recent_completions(student_id: @student.id, exercise_id: @exercise.id)
      end

      test "recent_completions_by_exercise : les 3 dernières fins de chaque exercice, en une requête, sans copie abandonnée ni autre élève" do
        other = create_exercise(essential: @exercise.essential) if @exercise.respond_to?(:essential)
        other ||= create_exercise
        [ 40, 30, 20, 10 ].each { |minutes| create_exercise_session(student: @student, exercise: @exercise, status: "completed", completed_at: @at - minutes.minutes) }
        create_exercise_session(student: @student, exercise: other, status: "completed", completed_at: @at)
        create_exercise_session(student: @student, exercise: other, status: "abandoned", completed_at: @at - 1.minute)

        result = nil
        queries = []
        counter = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
          result = @repository.recent_completions_by_exercise(student_id: @student.id, exercise_ids: [ @exercise.id, other.id ])
        end

        assert_equal 1, queries.size
        assert_equal [ @at - 10.minutes, @at - 20.minutes, @at - 30.minutes ], result[@exercise.id]
        assert_equal [ @at ], result[other.id]
        assert_empty @repository.recent_completions_by_exercise(student_id: @student.id, exercise_ids: [])
      end

      test "recent_completions : aucune copie terminée, une liste vide" do
        assert_empty @repository.recent_completions(student_id: @student.id, exercise_id: @exercise.id)
      end

      test "abandonne une session ouverte" do
        started = @repository.start(session: session)

        assert @repository.abandon(id: started.id, at: @at)
        assert_equal "abandoned", @repository.find_by_public_id(public_id: started.public_id).status
      end
    end
  end
end

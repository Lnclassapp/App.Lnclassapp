require "test_helper"

module UseCases
  module Assessment
    # prepare-interros-cahier, Lot C (CA-3, 5, 10, 17 ; ADR sujets-de-devoir §4) : « Vérifier ma réponse » ouvre une session neuve,
    # rend la copie et la ferme dans une seule transaction ; la pause, l'archivage et un devoir à rendre la refusent sans rien écrire.
    class CheckExerciseOnSheetTest < ActiveSupport::TestCase
      STUDENT = Entities::Identity::Actor.new(user_id: 7, role: :student)
      PUBLIC_ID = "ExErCiCe000040".freeze
      Answer = Entities::Assessment::Answer
      Question = Entities::Assessment::Question
      Session = Entities::Assessment::ExerciseSession

      # Comme StartExerciseSession : une session neuve, ou l'échec donné.
      class SpyStart
        attr_reader :calls

        def initialize(failure: nil, session_id: 100)
          @calls = []
          @failure = failure
          @session_id = session_id
        end

        def call(actor:, exercise_public_id:, restart:, attach_assignment:)
          @calls << { actor:, exercise_public_id:, restart:, attach_assignment: }
          return @failure if @failure

          Shared::Result.success(Session.new(id: @session_id, public_id: "sess#{@session_id}", student_id: actor.user_id, exercise_id: 40,
                                             status: "started", question_count: 2, answered_count: 0, correct_count: 0, progress_percent: 0,
                                             score_percent: nil, kind: "standard", knowledge_gap_id: nil, classroom_assignment_id: nil,
                                             started_at: Time.utc(2026, 10, 30), completed_at: nil))
        end
      end

      class SpySubmit
        attr_reader :dtos

        def initialize(failure: nil)
          @dtos = []
          @failure = failure
        end

        def call(actor:, dto:)
          @dtos << dto
          return @failure if @failure

          Shared::Result.success(SubmitExerciseCopy::Submitted.new(session_public_id: dto.session_public_id, already_closed: false, closed: nil))
        end
      end

      class FakeExercises
        include Ports::Assessment::ExerciseRepositoryPort

        def initialize(exercise) = @exercise = exercise
        def find_by_public_id(public_id:) = (@exercise if @exercise.public_id == public_id)
      end

      class FakePending
        include Ports::Assessment::PendingAssignmentRepositoryPort

        attr_reader :asked

        def initialize(*public_ids) = (@public_ids = public_ids; @asked = 0)

        def pending_exercise_public_ids(student_id:, exercise_public_ids:)
          @asked += 1
          Set.new(exercise_public_ids & @public_ids)
        end
      end

      class FakeAssignments
        include Ports::Classroom::AssignmentRepositoryPort

        def initialize(*assignments) = @assignments = assignments
        def find_by_public_id(public_id:) = @assignments.find { it.public_id == public_id }
      end

      class FakeMemberships
        include Ports::Classroom::MembershipRepositoryPort

        def initialize(classroom_id) = @classroom_id = classroom_id

        def primary_for(student_id:)
          Entities::Classroom::Membership.new(classroom_id: @classroom_id, student_id:, primary: true, joined_at: Time.utc(2026, 9, 1),
                                              left_at: nil, classroom_status: "active")
        end
      end

      def assignment(public_id: "AsSiGn00000001", classroom_id: 3, status: "active", key: PUBLIC_ID)
        Entities::Classroom::Assignment.new(id: 55, public_id:, classroom_id:, status:, assigned_by_id: 2, assigned_at: Time.utc(2026, 10, 1), archived_at: nil,
                                            assignable: Entities::Classroom::Assignable.new(type: "Exercise", id: 40, key:))
      end

      def question(id, type: "single_choice", answers: 4)
        Question.new(id:, position: id, content: "Q#{id}", explanation: nil, question_type: type,
                     answers: Array.new(answers) { |rank| Answer.new(id: id * 10 + rank, position: rank + 1, content: "P#{rank}", correct: rank.zero?) })
      end

      def exercise(questions: [ question(1), question(2) ])
        Entities::Assessment::Exercise.new(id: 40, public_id: PUBLIC_ID, essential_id: 9, title: "Méiose", exercise_type: "fixation",
                                           status: "published", parents_published: true, questions:)
      end

      def check(actor: STUDENT, answers: {}, pending: [], start: SpyStart.new, submit: SpySubmit.new, questions: nil,
                assignment_public_id: nil, assignments: [], classroom_id: 3, asked: PUBLIC_ID, status: "published")
        @start = start
        @submit = submit
        @pending = FakePending.new(*pending)
        @transaction = FakeTransaction.new
        exercise = questions ? exercise(questions:) : exercise()
        exercise.status = status
        CheckExerciseOnSheet.new(start:, submit:, exercises: FakeExercises.new(exercise), pending: @pending, transaction: @transaction,
                                 policy: Policies::Assessment::StartSessionPolicy.new,
                                 assignments: FakeAssignments.new(*assignments), memberships: FakeMemberships.new(classroom_id))
                            .call(actor:, exercise_public_id: asked, answers:, assignment_public_id:)
      end

      test "ouvre une session neuve (restart) puis rend la copie dans la même transaction" do
        result = check(answers: { "1" => { "display_order" => [ "0" ] } })

        assert result.success?
        assert_equal [ [ STUDENT, PUBLIC_ID, true ] ], @start.calls.map { [ it[:actor], it[:exercise_public_id], it[:restart] ] }
        assert_equal [ "sess100" ], @submit.dtos.map(&:session_public_id)
        assert_equal "sess100", result.value.session_public_id
        assert_equal 1, @transaction.calls
      end

      test "la pause (3 copies d'affilée) refuse sans rendre de copie et dit l'heure de reprise" do
        resume_at = Time.utc(2026, 10, 30, 10, 50)
        pause = Shared::Result.failure(:conflict, errors: { base: [ :paused ], resume_at: })

        result = check(start: SpyStart.new(failure: pause))

        assert_equal [ :conflict, [ :paused ], resume_at ], [ result.code, result.errors[:base], result.errors[:resume_at] ]
        assert_empty @submit.dtos
      end

      test "un exercice absent ou archivé est :not_found, sans session ni copie" do
        [ check(asked: "InConnu0000000"), check(status: "archived") ].each do |result|
          assert_equal :not_found, result.code
          assert_empty @start.calls
          assert_empty @submit.dtos
        end
      end

      test "un exercice assigné et pas encore rendu est refusé (:assigned_pending) sans ouvrir ni fermer de session (CA-17)" do
        result = check(pending: [ PUBLIC_ID ])

        assert_equal [ :conflict, [ :assigned_pending ] ], [ result.code, result.errors[:base] ]
        assert_empty @start.calls
        assert_empty @submit.dtos
        assert_equal 0, @transaction.calls
      end

      test "un autre exercice à rendre ne gêne pas celui-ci" do
        assert check(pending: [ "AuTrE000000000" ]).success?
      end

      test "un acteur qui n'est pas élève est refusé (:forbidden) sans interroger les devoirs" do
        teacher = Entities::Identity::Actor.new(user_id: 8, role: :teacher)

        assert_equal :forbidden, check(actor: teacher).code
        assert_equal 0, @pending.asked
        assert_empty @start.calls
      end

      test "une copie refusée annule la session ouverte : l'échec remonte et la transaction est annulée" do
        refused = Shared::Result.failure(:invalid, errors: { base: [ :invalid_copy ] })

        result = check(submit: SpySubmit.new(failure: refused))

        assert_equal [ :invalid, [ :invalid_copy ] ], [ result.code, result.errors[:base] ]
      end

      test "les indices de la feuille (ordre des positions) sont traduits dans l'ordre de la session (QCM)" do
        questions = [ question(1) ]
        session_order = Entities::Assessment::AnswerShuffle.for(session_id: 100, question_id: 1, ids: questions.first.answer_ids)
        right_id = questions.first.answers.find(&:correct).id

        # La feuille poste le rang dans l'ordre des positions : la bonne réponse est la première (indice 0).
        check(questions:, answers: { "1" => { "display_order" => [ "0" ] } })

        posted = @submit.dtos.sole.answers.fetch(1).display_order
        assert_equal [ session_order.index(right_id) ], posted
      end

      test "les indices d'un ordre ou d'un relier sont traduits du mélange de la feuille vers celui de la session" do
        ordering = question(1, type: "ordering")
        sheet_order = Entities::Assessment::AnswerShuffle.for(session_id: CheckExerciseOnSheet::SHEET_SEED, question_id: 1,
                                                              ids: ordering.answer_ids, avoid: ordering.ids_by_position)
        session_order = Entities::Assessment::AnswerShuffle.for(session_id: 100, question_id: 1, ids: ordering.answer_ids,
                                                                avoid: ordering.ids_by_position)
        # L'élève remet les étapes dans le bon ordre, tel qu'il les voit sur la feuille.
        posted = ordering.ids_by_position.map { sheet_order.index(it).to_s }

        check(questions: [ ordering ], answers: { "1" => { "display_order" => posted } })

        read = Entities::Assessment::AnswerShuffle.pick(session_order, @submit.dtos.sole.answers.fetch(1).display_order.map(&:to_i))
        assert_equal ordering.ids_by_position, read
      end

      test "un texte, une question inconnue et un indice illisible traversent tels quels" do
        answers = { "1" => { "response_text" => "AC" }, "99" => { "display_order" => [ "0" ] }, "2" => { "display_order" => [ "x" ] } }

        check(answers:)

        dto = @submit.dtos.sole
        assert_equal "AC", dto.answers.fetch(1).response_text
        assert_equal [ 0 ], dto.answers.fetch(99).display_order
        assert_equal [ -1 ], dto.answers.fetch(2).display_order
      end

      # CA-16 (memo Q17) : le rendu d'un devoir depuis « Ma classe ».
      test "sans devoir donné, la copie n'est rattachée à aucune assignation (entraînement)" do
        check

        assert_equal [ false ], @start.calls.map { it[:attach_assignment] }
      end

      test "« Rendre à l'enseignant » : l'assignation active de la classe de l'élève, qui porte l'exercice, reçoit la copie" do
        result = check(assignment_public_id: "AsSiGn00000001", assignments: [ assignment ], pending: [ PUBLIC_ID ])

        assert result.success?
        assert_equal [ true ], @start.calls.map { it[:attach_assignment] }
        assert_equal 1, @submit.dtos.size
      end

      test "une assignation inconnue, d'une autre classe ou d'un autre exercice est refusée (:forbidden) sans session" do
        [ [ [], 3 ], [ [ assignment ], 4 ], [ [ assignment(key: "AuTrE000000000") ], 3 ] ].each do |assignments, classroom_id|
          result = check(assignment_public_id: "AsSiGn00000001", assignments:, classroom_id:, pending: [ PUBLIC_ID ])

          assert_equal :forbidden, result.code
          assert_empty @start.calls
          assert_empty @submit.dtos
        end
      end

      test "une assignation archivée n'est plus à rendre (:conflict, :assignment_closed)" do
        result = check(assignment_public_id: "AsSiGn00000001", assignments: [ assignment(status: "archived") ], pending: [ PUBLIC_ID ])

        assert_equal [ :conflict, [ :assignment_closed ] ], [ result.code, result.errors[:base] ]
        assert_empty @start.calls
      end

      test "un devoir déjà rendu ne se rend pas deux fois (:conflict, :assignment_closed)" do
        result = check(assignment_public_id: "AsSiGn00000001", assignments: [ assignment ], pending: [])

        assert_equal [ :conflict, [ :assignment_closed ] ], [ result.code, result.errors[:base] ]
        assert_empty @start.calls
        assert_empty @submit.dtos
      end

      test "une copie qui n'est pas une liste de réponses est transmise telle quelle : la copie la refuse" do
        check(answers: "pas une liste")

        assert_not @submit.dtos.sole.valid?
      end

      test "SHEET_SEED est la graine de la feuille (PrepareSheetsQuery::SHEET_SEED)" do
        assert_equal Queries::Catalog::PrepareSheetsQuery::SHEET_SEED, CheckExerciseOnSheet::SHEET_SEED
      end
    end
  end
end

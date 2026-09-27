require "test_helper"

module UseCases
  module Assessment
    # AS-07, AS-08 (ADR-0028, ADR-0043, ADR-0048, ADR-0054) : tout exercice publié se démarre, assigné ou non ; une
    # session ouverte se reprend ; « Recommencer » l'abandonne ; une lacune en attente fait une remédiation.
    class StartExerciseSessionTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      STUDENT = Entities::Identity::Actor.new(user_id: 7, role: :student)
      Session = Entities::Assessment::ExerciseSession
      Answer = Entities::Assessment::Answer

      class FakeExercises
        include Ports::Assessment::ExerciseRepositoryPort

        def initialize(*exercises)
          @stored = exercises
        end

        def find_by_public_id(public_id:) = @stored.find { it.public_id == public_id }
      end

      # Comme le repository : une seule session ouverte par couple (élève, exercice).
      class FakeSessions
        include Ports::Assessment::ExerciseSessionRepositoryPort

        attr_reader :rows

        def initialize(*rows)
          @rows = rows
        end

        def started_for(student_id:, exercise_id:)
          @rows.find { it.student_id == student_id && it.exercise_id == exercise_id && it.started? }
        end

        def start(session:)
          existing = started_for(student_id: session.student_id, exercise_id: session.exercise_id)
          return existing if existing

          @rows << session.with(id: @rows.size + 100, public_id: "new#{@rows.size}")
          @rows.last
        end

        def abandon(id:, at:)
          index = @rows.index { it.id == id }
          @rows[index] = @rows[index].with(status: "abandoned")
          true
        end
      end

      class FakeGaps
        include Ports::Assessment::KnowledgeGapRepositoryPort

        def initialize(*gaps)
          @gaps = gaps
        end

        def pending_for(student_id:, essential_id:)
          @gaps.find { it.student_id == student_id && it.essential_id == essential_id && it.pending? }
        end
      end

      class FakeMemberships
        include Ports::Classroom::MembershipRepositoryPort

        def initialize(membership)
          @membership = membership
        end

        def primary_for(student_id:) = (@membership if @membership&.student_id == student_id)
      end

      class FakeAssignments
        include Ports::Classroom::AssignmentRepositoryPort

        def initialize(*assignments)
          @assignments = assignments
        end

        def active_for(classroom_id:, assignable:)
          @assignments.find { it.classroom_id == classroom_id && it.assignable == assignable && it.active? }
        end
      end

      def exercise(public_id: "ExErCiCe000040", id: 40, status: "published", parents_published: true, questions: 3)
        Entities::Assessment::Exercise.new(
          id:, public_id:, essential_id: 9, title: "Méiose", exercise_type: "fixation", status:, parents_published:,
          questions: Array.new(questions) do |index|
            Entities::Assessment::Question.new(id: index + 1, position: index + 1, content: "Q", explanation: nil,
                                               question_type: "true_false",
                                               answers: [ Answer.new(id: 1, position: 1, content: "Vrai", correct: true) ])
          end
        )
      end

      def stored_session(id:, status: "started", student_id: 7, exercise_id: 40)
        Session.new(id:, public_id: "old#{id}", student_id:, exercise_id:, status:, question_count: 3, answered_count: 1,
                    correct_count: 1, progress_percent: 33, score_percent: nil, kind: "standard", knowledge_gap_id: nil,
                    classroom_assignment_id: nil, started_at: NOW - 3600, completed_at: nil)
      end

      def membership(classroom_status: "active")
        Entities::Classroom::Membership.new(classroom_id: 3, student_id: 7, primary: true, joined_at: NOW, left_at: nil,
                                            classroom_status:)
      end

      def assignment(status: "active", assignable_id: 40)
        Entities::Classroom::Assignment.new(
          id: 55, public_id: "asg", classroom_id: 3, status:, assigned_by_id: 2, assigned_at: NOW, archived_at: nil,
          assignable: Entities::Classroom::Assignable.new(type: "Exercise", id: assignable_id, key: "ExErCiCe000040")
        )
      end

      def start(actor: STUDENT, public_id: "ExErCiCe000040", restart: false, exercises: [ exercise ], sessions: [], gaps: [],
                membership: nil, assignments: [])
        @sessions = FakeSessions.new(*sessions)
        @transaction = FakeTransaction.new
        StartExerciseSession.new(
          exercises: FakeExercises.new(*exercises), sessions: @sessions, gaps: FakeGaps.new(*gaps),
          memberships: FakeMemberships.new(membership), assignments: FakeAssignments.new(*assignments),
          policy: Policies::Assessment::StartSessionPolicy.new, transaction: @transaction, clock: Clock.new(NOW)
        ).call(actor:, exercise_public_id: public_id, restart:)
      end

      test "un exercice publié non assigné se démarre : session ouverte, nombre de questions figé, rattachée à rien" do
        result = start

        assert result.success?
        session = @sessions.rows.sole
        assert_equal session, result.value
        assert_equal [ 7, 40, "started", 3, 0, 0, 0 ],
                     [ session.student_id, session.exercise_id, session.status, session.question_count,
                       session.answered_count, session.correct_count, session.progress_percent ]
        assert_equal [ "standard", nil, nil, NOW ],
                     [ session.kind, session.knowledge_gap_id, session.classroom_assignment_id, session.started_at ]
        assert_nil session.score_percent
        assert_equal 1, @transaction.calls
      end

      test "assigné à la classe principale active de l'élève : la session est rattachée à l'assignation" do
        result = start(membership: membership, assignments: [ assignment ])

        assert_equal 55, result.value.classroom_assignment_id
      end

      test "une assignation retirée, d'un autre exercice ou d'une classe archivée ne rattache pas la session" do
        assert_nil start(membership: membership, assignments: [ assignment(status: "archived") ]).value.classroom_assignment_id
        assert_nil start(membership: membership, assignments: [ assignment(assignable_id: 41) ]).value.classroom_assignment_id
        assert_nil start(membership: membership(classroom_status: "archived"), assignments: [ assignment ])
          .value.classroom_assignment_id
      end

      test "une session ouverte est reprise telle quelle, rien n'est créé" do
        open = stored_session(id: 5)
        result = start(sessions: [ open ])

        assert_equal open, result.value
        assert_equal [ open ], @sessions.rows
      end

      test "une session terminée ou abandonnée ne se reprend pas : une nouvelle commence" do
        result = start(sessions: [ stored_session(id: 5, status: "completed"), stored_session(id: 6, status: "abandoned") ])

        assert_equal 3, @sessions.rows.size
        assert_equal "started", result.value.status
        assert_not_includes [ 5, 6 ], result.value.id
      end

      test "Recommencer abandonne la session ouverte et en ouvre une nouvelle" do
        result = start(sessions: [ stored_session(id: 5) ], restart: true)

        old, fresh = @sessions.rows
        assert_equal "abandoned", old.status
        assert_equal [ "started", 0 ], [ fresh.status, fresh.answered_count ]
        assert_equal fresh, result.value
      end

      test "Recommencer sans session ouverte démarre simplement" do
        assert start(restart: true).success?
        assert_equal [ "started" ], @sessions.rows.map(&:status)
      end

      test "une lacune en attente sur la fiche fait une session de remédiation" do
        gap = Entities::Assessment::KnowledgeGap.new(id: 70, student_id: 7, essential_id: 9, status: "pending", failed_sessions_count: 1)
        result = start(gaps: [ gap ])

        assert_equal [ "remediation", 70 ], [ result.value.kind, result.value.knowledge_gap_id ]
      end

      test "une lacune résolue ne change rien : session standard" do
        gap = Entities::Assessment::KnowledgeGap.new(id: 70, student_id: 7, essential_id: 9, status: "remediated", failed_sessions_count: 1)

        assert_equal "standard", start(gaps: [ gap ]).value.kind
      end

      test "brouillon, ou publié dans une fiche en brouillon : 404, rien n'est créé" do
        assert_equal :not_found, start(exercises: [ exercise(status: "draft") ]).code
        assert_equal :not_found, start(exercises: [ exercise(parents_published: false) ]).code
        assert_empty @sessions.rows
        assert_equal 0, @transaction.calls
      end

      test "exercice inconnu : 404" do
        assert_equal :not_found, start(public_id: "inconnu").code
      end

      test "un enseignant ou l'équipe ne démarre pas de session : 403, rien n'est créé" do
        assert_equal :forbidden, start(actor: Entities::Identity::Actor.new(user_id: 2, role: :teacher)).code
        assert_equal :forbidden, start(actor: Entities::Identity::Actor.new(user_id: 3, role: :team)).code
        assert_equal :forbidden, start(actor: nil).code
        assert_empty @sessions.rows
      end
    end
  end
end

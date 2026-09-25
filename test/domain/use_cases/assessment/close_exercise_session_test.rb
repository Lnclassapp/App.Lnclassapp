require "test_helper"

module UseCases
  module Assessment
    # AS-11 (ADR-0033, ADR-0043, ADR-0054) : la clôture recalcule le score depuis les tentatives, monte le badge vers un
    # palier strictement supérieur seulement, et ouvre, compte ou résout la lacune de la fiche.
    class CloseExerciseSessionTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      STUDENT = Entities::Identity::Actor.new(user_id: 7, role: :student)
      Attempt = Entities::Assessment::QuestionAttempt

      class FakeSessions
        include Ports::Assessment::ExerciseSessionRepositoryPort

        attr_reader :completed

        def initialize(attempts)
          @attempts = attempts
          @completed = []
        end

        def attempts(session_id:) = @attempts.select { it.session_id == session_id }

        def complete(id:, score_percent:, at:)
          @completed << [ id, score_percent, at ]
          true
        end
      end

      class FakeBadges
        include Ports::Assessment::BadgeRepositoryPort

        attr_reader :upserts

        def initialize(badge)
          @badge = badge
          @upserts = []
        end

        def find(student_id:, exercise_id:) = (@badge if @badge && [ @badge.student_id, @badge.exercise_id ] == [ student_id, exercise_id ])

        def upsert(badge:)
          @upserts << badge
          badge
        end
      end

      class FakeGaps
        include Ports::Assessment::KnowledgeGapRepositoryPort

        attr_reader :calls

        def initialize(gap)
          @gap = gap
          @calls = []
        end

        def pending_for(student_id:, essential_id:)
          @gap if @gap && [ @gap.student_id, @gap.essential_id ] == [ student_id, essential_id ]
        end

        def open(**args) = @calls << [ :open, args ]
        def increment(**args) = @calls << [ :increment, args ]
        def resolve(**args) = @calls << [ :resolve, args ]
      end

      def session(question_count: 100, kind: "standard", status: "started")
        Entities::Assessment::ExerciseSession.new(
          id: 5, public_id: "SeSsIoN0000005", student_id: 7, exercise_id: 40, status:, question_count:, answered_count: question_count,
          correct_count: 0, progress_percent: 100, score_percent: nil, kind:, knowledge_gap_id: (70 if kind == "remediation"),
          classroom_assignment_id: nil, started_at: NOW - 600, completed_at: nil
        )
      end

      # correct bonnes réponses sur total, plus une tentative d'une autre session qui ne doit pas compter.
      def attempts(correct, total)
        Array.new(total) { |index| Attempt.new(session_id: 5, question_id: index, selected_answer_ids: [ 1 ], correct: index < correct, answered_at: NOW) } +
          [ Attempt.new(session_id: 6, question_id: 1, selected_answer_ids: [ 1 ], correct: true, answered_at: NOW) ]
      end

      def badge(level) = Entities::Assessment::Badge.new(student_id: 7, exercise_id: 40, session_id: 1, level:, awarded_at: NOW - 86_400)
      def gap = Entities::Assessment::KnowledgeGap.new(id: 70, student_id: 7, essential_id: 9, status: "pending", failed_sessions_count: 1)

      def close(correct:, total: 100, actor: STUDENT, current_badge: nil, pending_gap: nil, kind: "standard", status: "started")
        @sessions = FakeSessions.new(attempts(correct, total))
        @badges = FakeBadges.new(current_badge)
        @gaps = FakeGaps.new(pending_gap)
        @transaction = FakeTransaction.new
        CloseExerciseSession.new(sessions: @sessions, badges: @badges, gaps: @gaps, policy: Policies::Assessment::SubmitAttemptPolicy.new,
                                 transaction: @transaction, clock: Clock.new(NOW))
                            .call(actor:, session: session(question_count: total, kind:, status:), essential_id: 9)
      end

      test "bornes du barème : 49 rien, 50 Bronze, 69 Bronze, 70 Argent, 79 Argent, 80 Or, 99 Or, 100 Diamant" do
        { 49 => nil, 50 => :bronze, 69 => :bronze, 70 => :silver, 79 => :silver, 80 => :gold, 99 => :gold, 100 => :diamond }
          .each do |score, level|
            row = close(correct: score).value

            assert_equal [ score, level ], [ row.score_percent, row.badge_level ], "score #{score}"
            assert_equal [ [ 5, score, NOW ] ], @sessions.completed
          end
      end

      test "le score vient des tentatives de la session, en division entière : 9 sur 10 donne 90 et Or, jamais Diamant" do
        row = close(correct: 9, total: 10).value

        assert_equal [ 90, :gold, true ], [ row.score_percent, row.badge_level, row.earned_now ]
        assert_equal 1, @transaction.calls
      end

      test "premier badge : créé, avec la session qui l'obtient" do
        row = close(correct: 80).value

        assert row.earned_now
        awarded = @badges.upserts.sole
        assert_equal [ 7, 40, 5, :gold, NOW ], [ awarded.student_id, awarded.exercise_id, awarded.session_id, awarded.level, awarded.awarded_at ]
      end

      test "un badge n'est remplacé que par un palier strictement supérieur" do
        assert close(correct: 100, current_badge: badge(:gold)).value.earned_now
        assert_equal [ :diamond ], @badges.upserts.map(&:level)

        assert_not close(correct: 85, current_badge: badge(:gold)).value.earned_now
        assert_not close(correct: 70, current_badge: badge(:gold)).value.earned_now
        assert_empty @badges.upserts
      end

      test "sous le seuil, aucun badge n'est écrit" do
        row = close(correct: 40).value

        assert_equal [ nil, false ], [ row.badge_level, row.earned_now ]
        assert_empty @badges.upserts
      end

      test "échec sans lacune en attente : une lacune est ouverte sur la fiche" do
        close(correct: 40)

        assert_equal [ [ :open, { student_id: 7, essential_id: 9, source_session_id: 5, at: NOW } ] ], @gaps.calls
      end

      test "échec avec une lacune en attente : elle compte un échec de plus" do
        close(correct: 49, pending_gap: gap)

        assert_equal [ [ :increment, { id: 70 } ] ], @gaps.calls
      end

      test "réussite d'une remédiation : la lacune est remédiée" do
        close(correct: 70, pending_gap: gap, kind: "remediation")

        assert_equal [ [ :resolve, { id: 70, status: "remediated", session_id: 5, at: NOW } ] ], @gaps.calls
      end

      test "réussite d'une session standard : la lacune est auto-corrigée" do
        close(correct: 50, pending_gap: gap)

        assert_equal [ [ :resolve, { id: 70, status: "self_corrected", session_id: 5, at: NOW } ] ], @gaps.calls
      end

      test "réussite sans lacune : rien sur les lacunes" do
        close(correct: 100)

        assert_empty @gaps.calls
      end

      test "refus : un autre élève, ou une session déjà close, ne termine rien" do
        other = Entities::Identity::Actor.new(user_id: 8, role: :student)

        assert_equal :forbidden, close(correct: 100, actor: other).code
        assert_equal :forbidden, close(correct: 100, status: "completed").code
        assert_empty @sessions.completed
        assert_equal 0, @transaction.calls
      end
    end
  end
end

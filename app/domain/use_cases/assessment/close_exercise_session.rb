# 🧠 DOMAINE · UseCases::Assessment::CloseExerciseSession
# Rôle : seul point qui termine une session : score recalculé des tentatives, badge monté, lacune ouverte ou résolue
# ADR  : 0026, 0033, 0043, 0054
module UseCases
  module Assessment
    class CloseExerciseSession
      # badge_level : palier atteint par cette session (nil sous le seuil) ; earned_now : le badge de l'élève vient de monter.
      Row = Data.define(:score_percent, :badge_level, :earned_now)

      def initialize(sessions:, badges:, gaps:, policy:, transaction:, clock:)
        @sessions = sessions
        @badges = badges
        @gaps = gaps
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # Appelé par SubmitQuestionAttempt, dans sa transaction, à la dernière réponse.
      # session : Entities::Assessment::ExerciseSession ouverte ; essential_id : fiche de son exercice.
      # → Result(Row) | :forbidden
      def call(actor:, session:, essential_id:)
        allowed = @policy.call(actor:, session:)
        return allowed if allowed.failure?

        @transaction.call { Shared::Result.success(close(session, essential_id, @clock.now)) }
      end

      private

      def close(session, essential_id, now)
        correct = @sessions.attempts(session_id: session.id).count(&:correct)
        score_percent = Entities::Assessment::Grading.score_percent(correct:, total: session.question_count)
        @sessions.complete(id: session.id, score_percent:, at: now)
        badge_level = Entities::Assessment::Grading.badge_for(score_percent)
        earned_now = award(session, badge_level, now)
        settle_gap(session, essential_id, score_percent, now)
        Row.new(score_percent:, badge_level:, earned_now:)
      end

      # Un badge ne monte que vers un palier strictement supérieur (ADR-0033).
      def award(session, badge_level, now)
        current = @badges.find(student_id: session.student_id, exercise_id: session.exercise_id)
        return false unless Entities::Assessment::Grading.upgrade?(current_level(current), badge_level)

        @badges.upsert(badge: Entities::Assessment::Badge.new(student_id: session.student_id, exercise_id: session.exercise_id,
                                                              session_id: session.id, level: badge_level, awarded_at: now))
        true
      end

      def current_level(badge)
        badge.level if badge
      end

      # ADR-0043 : ouverte sous le seuil, comptée à chaque nouvel échec, résolue par une réussite.
      def settle_gap(session, essential_id, score_percent, now)
        pending = @gaps.pending_for(student_id: session.student_id, essential_id:)
        decision = Entities::Assessment::GapDecision.call(score_percent:, pending_gap: pending, session_kind: session.kind)
        return if decision == :none
        return @gaps.open(student_id: session.student_id, essential_id:, source_session_id: session.id, at: now) if decision == :open
        return @gaps.increment(id: pending.id) if decision == :increment

        @gaps.resolve(id: pending.id, status: decision.to_s, session_id: session.id, at: now)
      end
    end
  end
end

# 🧠 DOMAINE · UseCases::Assessment::CloseExerciseSession
# Rôle : seul point qui termine une session : score recalculé des tentatives, badge monté, lacune ouverte ou résolue
# ADR  : 0026, 0033, 0043, 0054, 0112, 0113 (§4.2 : un exercice de toute la leçon n'ouvre ni ne lève aucune lacune), 0115 (score en points), médailles-lues-a-la-cloture, 0120-questions-a-plusieurs-cases-et-indice (§6 : score en fractions de points)
module UseCases
  module Assessment
    class CloseExerciseSession
      # badge_level : médaille enregistrée par cette session (Bronze dès une réponse, nil pour une copie vide) ; earned_now : le badge de l'élève vient de monter.
      Row = Data.define(:score_percent, :badge_level, :earned_now)

      def initialize(sessions:, exercises:, badges:, gaps:, policy:, transaction:, clock:)
        @sessions = sessions
        @exercises = exercises
        @badges = badges
        @gaps = gaps
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # Appelé par SubmitExerciseCopy, dans sa transaction.
      # session : Entities::Assessment::ExerciseSession ouverte ; essential_id : notion de son exercice, nil pour toute la leçon.
      # → Result(Row) | :forbidden
      def call(actor:, session:, essential_id:)
        allowed = @policy.call(actor:, session:)
        return allowed if allowed.failure?

        @transaction.call { Shared::Result.success(close(session, essential_id, @clock.now)) }
      end

      private

      def close(session, essential_id, now)
        score_percent = Entities::Assessment::Grading.points_percent(graded(session))
        @sessions.complete(id: session.id, score_percent:, at: now)
        badge_level = recorded_level(session, score_percent)
        earned_now = award(session, badge_level, now)
        settle_gap(session, essential_id, score_percent, now)
        Row.new(score_percent:, badge_level:, earned_now:)
      end

      # ADR médailles lues à la clôture : le palier du score (Bronze au moins, Grading.badge_for) si au moins une réponse a été donnée
      # (tentative non unanswered) ; nil pour une copie sans aucune réponse. Cette médaille est celle que les écrans lisent.
      def recorded_level(session, score_percent)
        return unless @sessions.attempts(session_id: session.id).any? { !it.unanswered }

        Entities::Assessment::Grading.badge_for(score_percent)
      end

      # [[points, part juste]] des seules questions corrigées automatiquement de l'exercice : une réponse rédigée ou un cahier ne compte
      # jamais, une question sans tentative est fausse, une tentative d'une autre question est ignorée (menace I11). La part juste
      # est 1 ou 0 pour une case, cases justes / cases sinon (Grading.share).
      def graded(session)
        attempts = @sessions.attempts(session_id: session.id).to_h { [ it.question_id, it ] }
        @exercises.find(id: session.exercise_id).questions.select(&:auto_graded?)
                  .map { |question| [ question.points, Entities::Assessment::Grading.share(question, attempts[question.id]) ] }
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
        return if essential_id.nil?

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

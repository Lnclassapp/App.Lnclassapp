# 🧠 DOMAINE · UseCases::Assessment::StartExerciseSession
# Rôle : l'élève démarre ou reprend un exercice publié ; « Recommencer » abandonne la session ouverte et en ouvre une autre
# ADR  : 0026, 0028, 0043, 0048, 0054
module UseCases
  module Assessment
    class StartExerciseSession
      def initialize(exercises:, sessions:, gaps:, memberships:, assignments:, policy:, transaction:, clock:)
        @exercises = exercises
        @sessions = sessions
        @gaps = gaps
        @memberships = memberships
        @assignments = assignments
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # → Result(ExerciseSession) | :not_found (exercice absent, ou non publié : le brouillon n'existe pas pour l'élève)
      #   | :forbidden
      def call(actor:, exercise_public_id:, restart: false)
        exercise = @exercises.find_by_public_id(public_id: exercise_public_id)
        return Shared::Result.failure(:not_found) if exercise.nil?

        allowed = @policy.call(actor:, exercise:)
        return Shared::Result.failure(:not_found) if allowed.errors.fetch(:base, []).include?(:not_published)
        return allowed if allowed.failure?

        @transaction.call { Shared::Result.success(open_session(actor, exercise, restart)) }
      end

      private

      # L'index partiel tranche un double clic : start renvoie alors la session déjà ouverte.
      def open_session(actor, exercise, restart)
        current = @sessions.started_for(student_id: actor.user_id, exercise_id: exercise.id)
        return current if current && !restart

        @sessions.abandon(id: current.id, at: @clock.now) if current
        @sessions.start(session: new_session(actor, exercise))
      end

      # Le nombre de questions est figé au démarrage (ADR-0054) ; une lacune en attente fait une remédiation (ADR-0043).
      def new_session(actor, exercise)
        gap = @gaps.pending_for(student_id: actor.user_id, essential_id: exercise.essential_id)
        Entities::Assessment::ExerciseSession.new(
          id: nil, public_id: nil, student_id: actor.user_id, exercise_id: exercise.id, status: "started",
          question_count: exercise.questions.size, answered_count: 0, correct_count: 0, progress_percent: 0,
          score_percent: nil, kind: gap ? "remediation" : "standard", knowledge_gap_id: gap_id(gap),
          classroom_assignment_id: assignment_id(actor, exercise), started_at: @clock.now, completed_at: nil
        )
      end

      def gap_id(gap)
        gap.id if gap
      end

      # Rattachée à l'assignation active de l'exercice dans la classe principale de l'élève (ADR-0048), sinon à rien.
      def assignment_id(actor, exercise)
        membership = @memberships.primary_for(student_id: actor.user_id)
        return unless membership && membership.classroom_active?

        assignable = Entities::Classroom::Assignable.new(type: "Exercise", id: exercise.id, key: exercise.public_id)
        assignment = @assignments.active_for(classroom_id: membership.classroom_id, assignable:)
        assignment.id if assignment
      end
    end
  end
end

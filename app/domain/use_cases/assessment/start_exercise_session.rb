# 🧠 DOMAINE · UseCases::Assessment::StartExerciseSession
# Rôle : l'élève démarre ou reprend un exercice publié ; « Recommencer » abandonne la session ouverte et en ouvre une autre
# ADR  : 0026, 0028, 0043, 0048, 0054, 0115, 0121 (attach_assignment)
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
      #   | :forbidden | :conflict (en pause après 3 copies d'affilée, ADR-0115 : errors base [:paused] et resume_at, l'heure de reprise)
      #   attach_assignment: false → la session n'est rattachée à aucune assignation (copie d'entraînement refaite après le rendu d'un devoir)
      def call(actor:, exercise_public_id:, restart: false, attach_assignment: true)
        exercise = @exercises.find_by_public_id(public_id: exercise_public_id)
        return Shared::Result.failure(:not_found) if exercise.nil?

        allowed = @policy.call(actor:, exercise:)
        return Shared::Result.failure(:not_found) if allowed.errors.fetch(:base, []).include?(:not_published)
        return allowed if allowed.failure?

        @transaction.call { open_session(actor, exercise, restart, attach_assignment) }
      end

      private

      # L'index partiel tranche un double clic : start renvoie alors la session déjà ouverte.
      # Reprendre la copie ouverte n'est pas une nouvelle copie : la pause ne la touche pas.
      def open_session(actor, exercise, restart, attach_assignment)
        current = @sessions.started_for(student_id: actor.user_id, exercise_id: exercise.id)
        return Shared::Result.success(current) if current && !restart

        resume_at = paused_until(actor, exercise)
        return Shared::Result.failure(:conflict, errors: { base: [ :paused ], resume_at: }) if resume_at

        Shared::Result.success(begin_session(actor, exercise, current, attach_assignment))
      end

      def paused_until(actor, exercise)
        completions = @sessions.recent_completions(student_id: actor.user_id, exercise_id: exercise.id)
        Entities::Assessment::RestartPause.resume_at(completions:, now: @clock.now)
      end

      def begin_session(actor, exercise, current, attach_assignment)
        @sessions.abandon(id: current.id, at: @clock.now) if current
        @sessions.start(session: new_session(actor, exercise, attach_assignment))
      end

      # Le nombre de questions est figé au démarrage (ADR-0054) ; une lacune en attente fait une remédiation (ADR-0043).
      def new_session(actor, exercise, attach_assignment)
        gap = @gaps.pending_for(student_id: actor.user_id, essential_id: exercise.essential_id)
        Entities::Assessment::ExerciseSession.new(
          id: nil, public_id: nil, student_id: actor.user_id, exercise_id: exercise.id, status: "started",
          question_count: exercise.questions.size, answered_count: 0, correct_count: 0, progress_percent: 0,
          score_percent: nil, kind: gap ? "remediation" : "standard", knowledge_gap_id: gap_id(gap),
          classroom_assignment_id: (assignment_id(actor, exercise) if attach_assignment), started_at: @clock.now, completed_at: nil
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

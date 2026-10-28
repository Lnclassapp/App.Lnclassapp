# 🧠 DOMAINE · UseCases::Assessment::UpdateExercise
# Rôle : l'équipe modifie un exercice ; après une première session, seuls son titre et sa description changent
# ADR  : 0026, 0028, 0035, 0036, 0054, 0105 · UDR : 0017
module UseCases
  module Assessment
    class UpdateExercise
      # Une question cite une image qu'elle ne peut plus prendre (ADR-0105) : rien n'est écrit, le formulaire le dit.
      IMAGE_UNAVAILABLE = Shared::Result.failure(:invalid, errors: { questions: [ :image_unavailable ] })

      def initialize(exercises:, transaction:, policy:)
        @exercises = exercises
        @transaction = transaction
        @policy = policy
      end

      # dto : Dtos::Assessment::ExerciseInput. Sans session, ses questions remplacent toutes les questions enregistrées.
      # → Result(Exercise) | :forbidden | :not_found | :invalid (dont base: [:questions_locked], questions: [:image_unavailable]) | :conflict
      def call(actor:, public_id:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        current = @exercises.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if current.nil?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        locked = current.questions_locked?(has_attempts: @exercises.has_sessions?(exercise_id: current.id))
        return Shared::Result.failure(:invalid, errors: { base: [ :questions_locked ] }) if locked && changes_questions?(current, dto)

        exercise = rebuild(current, dto, locked)
        errors = errors_of(current, exercise)
        return Shared::Result.failure(:invalid, errors:) if errors.any?

        @transaction.attempt { @exercises.update(exercise:, replace_questions: !locked) }
      rescue Ports::Assessment::ExerciseRepositoryPort::ImageUnavailable
        IMAGE_UNAVAILABLE
      end

      private

      # Verrouillé, le formulaire n'envoie ni question ni autre type (ADR-0036) : tout écart est une saisie forgée.
      def changes_questions?(current, dto)
        dto.questions.any? || dto.exercise_type != current.exercise_type
      end

      # Identité, place, auteur et statut viennent de l'exercice enregistré, jamais de la saisie.
      def rebuild(current, dto, locked)
        Entities::Assessment::Exercise.new(
          id: current.id, public_id: current.public_id, course_id: current.course_id, essential_id: current.essential_id, position: current.position,
          author_id: current.author_id, status: current.status, published_at: current.published_at,
          archived_at: current.archived_at, parents_published: current.parents_published, title: dto.title,
          statement: dto.statement, exercise_type: dto.exercise_type,
          questions: locked ? current.questions : dto.question_entities
        )
      end

      # Invariants, structure de chaque question, puis, tant que l'exercice est publié, au moins une question et ses images
      # complètes (ADR-0074 §4.2, ADR-0105 §4.4) : une question qui attend son image, ou dont l'image n'a pas de texte de
      # remplacement, est refusée comme à la publication.
      def errors_of(current, exercise)
        return exercise.errors.to_hash unless exercise.valid?

        errors = exercise.questions.each_with_index.filter_map do |question, index|
          [ :"questions[#{index}]", question.structure_errors ] if question.structure_errors.any?
        end.to_h
        errors[:questions] = [ :needed_while_published ] if current.published? && exercise.questions.empty?
        errors.merge(published_image_errors(current, exercise)) { |_question, rules, images| rules + images }
      end

      def published_image_errors(current, exercise)
        return {} unless current.published?

        exercise.image_errors.to_h { |number, codes| [ :"questions[#{number - 1}]", [ codes.first ] ] }
      end
    end
  end
end

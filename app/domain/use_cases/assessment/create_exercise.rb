# 🧠 DOMAINE · UseCases::Assessment::CreateExercise
# Rôle : l'équipe crée en brouillon un exercice d'une fiche essentielle, avec ses questions et propositions, en une écriture
# ADR  : 0026, 0028, 0035, 0039, 0054, 0105 · UDR : 0017
module UseCases
  module Assessment
    class CreateExercise
      # Une question cite une image qu'elle ne peut plus prendre (ADR-0105) : rien n'est écrit, le formulaire le dit.
      IMAGE_UNAVAILABLE = Shared::Result.failure(:invalid, errors: { questions: [ :image_unavailable ] })

      def initialize(exercises:, essentials:, transaction:, policy:)
        @exercises = exercises
        @essentials = essentials
        @transaction = transaction
        @policy = policy
      end

      # dto : Dtos::Assessment::ExerciseInput.
      # → Result(Exercise) | :forbidden | :not_found | :invalid (dont « questions[i] » : erreurs de structure ; questions: [:image_unavailable]) | :conflict
      def call(actor:, essential_slug:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        essential = @essentials.find_by_slug(slug: essential_slug)
        return Shared::Result.failure(:not_found) if essential.nil?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        exercise = Entities::Assessment::Exercise.new(
          course_id: essential.course_id, essential_id: essential.id, author_id: actor.user_id, status: "draft", title: dto.title,
          statement: dto.statement, exercise_type: dto.exercise_type, questions: dto.question_entities
        )
        errors = errors_of(exercise)
        return Shared::Result.failure(:invalid, errors:) if errors.any?

        @transaction.attempt { @exercises.create(exercise:) }
      rescue Ports::Assessment::ExerciseRepositoryPort::ImageUnavailable
        IMAGE_UNAVAILABLE
      end

      private

      # Invariants de l'exercice, puis structure de chaque question selon son type, à la place de la question.
      def errors_of(exercise)
        return exercise.errors.to_hash unless exercise.valid?

        exercise.questions.each_with_index.filter_map do |question, index|
          [ :"questions[#{index}]", question.structure_errors ] if question.structure_errors.any?
        end.to_h
      end
    end
  end
end

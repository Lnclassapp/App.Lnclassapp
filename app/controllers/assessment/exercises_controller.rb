# 🌐 DELIVERY · Assessment::ExercisesController
# Rôle : page d'un exercice (AS-02) ; propositions correctes pour l'équipe et l'enseignant, jamais pour l'élève (AS-39)
# ADR  : 0026, 0028, 0054 · UDR : 0006, 0007, 0021 · sécurité n° 29
module Assessment
  class ExercisesController < AuthenticatedController
    include ReadsOwnLevel

    def show
      exercise = Repositories::Assessment::ExerciseRepository.new.find_by_public_id(public_id: params[:public_id])
      return render_not_found if exercise.nil?
      return if refuse_out_of_level(exercise_public_id: exercise.public_id)

      render_result Policies::Catalog::ReadPublishedPolicy.new.call(actor: current_actor, content: exercise),
                    success: ->(_) { load_page(exercise) }
    end

    private

    # L'entité porte les propositions correctes : elle ne sert qu'aux policies, et au panneau de statut de l'équipe.
    # La vue lit la query, qui ne sélectionne answers.correct que si RevealAnswersPolicy l'accorde.
    def load_page(exercise)
      @reveal = Policies::Assessment::RevealAnswersPolicy.new.call(actor: current_actor, exercise:).success?
      @detail = Queries::Assessment::ExerciseDetailQuery.new.call(public_id: exercise.public_id, reveal: @reveal)
      @status_record = exercise if Policies::Catalog::ManageContentPolicy.new.call(actor: current_actor).success?
      @progress = progress(exercise) if Policies::Assessment::StartSessionPolicy.new.call(actor: current_actor, exercise:).success?
    end

    def progress(exercise)
      Queries::Assessment::ExerciseProgressQuery.new.call(student_id: current_actor.user_id, exercise_id: exercise.id)
    end
  end
end

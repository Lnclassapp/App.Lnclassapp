# 🌐 DELIVERY · Teams::ExercisesController
# Rôle : l'équipe crée et modifie en modale un exercice, ses questions et propositions ; le publie ou l'archive
# ADR  : 0026, 0028, 0035, 0036, 0054 · UDR : 0006, 0017
module Teams
  class ExercisesController < BaseController
    before_action :load_essential, only: %i[new create]
    before_action :load_exercise, only: %i[edit update]

    def new
      @form = Dtos::Assessment::ExerciseInput.new(exercise_type: Entities::Assessment::Exercise::TYPES.first)
    end

    def create
      @form = form_input
      render_result create_exercise.call(actor: current_actor, essential_slug: @essential.slug, dto: @form), form: :new,
                    success: ->(exercise) { respond_written(exercise, :created) }
    end

    # Le formulaire montre les propositions correctes : RevealAnswersPolicy, comme tout écran qui les rend.
    def edit
      render_result reveal_answers.call(actor: current_actor, exercise: @exercise),
                    success: ->(_) { @form = Dtos::Assessment::ExerciseInput.from_exercise(@exercise) }
    end

    def update
      @form = form_input
      render_result update_exercise.call(actor: current_actor, public_id: @exercise.public_id, dto: @form), form: :edit,
                    success: ->(exercise) { respond_written(exercise, :updated) }
    end

    def publish = change_status(publish_exercise)
    def archive = change_status(archive_exercise)

    private

    def load_essential
      @essential = Repositories::Catalog::EssentialRepository.new.find_by_slug(slug: params[:essential_slug])
      render_not_found if @essential.nil?
    end

    # Questions verrouillées dès la première session (ADR-0036) : le formulaire n'offre plus que titre et description.
    def load_exercise
      @exercise = exercises.find_by_public_id(public_id: params[:public_id])
      return render_not_found if @exercise.nil?

      @questions_locked = @exercise.questions_locked?(has_attempts: exercises.has_sessions?(exercise_id: @exercise.id))
    end

    # Questions et propositions arrivent indexées par fields_for, ou par le clonage du contrôleur nested-form.
    def form_input
      Dtos::Assessment::ExerciseInput.from_params(params.expect(exercise: [
        :title, :description, :exercise_type,
        { questions_attributes: [ [ :content, :explanation, :question_type, { answers_attributes: [ [ :content, :correct ] ] } ] ] }
      ]).to_h)
    end

    # La page hôte (fiche essentielle, exercice) appartient à d'autres lots : le stream la rafraîchit par morphing.
    def respond_written(exercise, message)
      @exercise = exercise
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to exercise_path(exercise.public_id), notice: t(".#{message}", title: exercise.title), status: :see_other }
      end
    end

    def change_status(use_case)
      result = use_case.call(actor: current_actor, public_id: params[:public_id])
      return refuse_transition(result) if result.code == :conflict

      render_result result, success: lambda { |exercise|
        @exercise = exercise
        respond_to do |format|
          format.turbo_stream { render :transition }
          format.html do
            redirect_to exercise_path(exercise.public_id), status: :see_other,
                                                           notice: t("teams.exercises.transition.#{exercise.status}", title: exercise.title)
          end
        end
      }
    end

    # Refus d'une transition (sans question, fiche non publiée, retour interdit) : toast d'erreur qui en dit la raison.
    def refuse_transition(result)
      @refusal = t("teams.exercises.transition.refusals.#{result.errors.fetch(:base).first}")
      respond_to do |format|
        format.turbo_stream { render :transition, status: :unprocessable_entity }
        format.html { redirect_to exercise_path(params[:public_id]), alert: @refusal, status: :see_other }
      end
    end

    def exercises = @exercises ||= Repositories::Assessment::ExerciseRepository.new
    def reveal_answers = Policies::Assessment::RevealAnswersPolicy.new

    def create_exercise
      UseCases::Assessment::CreateExercise.new(exercises:, essentials: Repositories::Catalog::EssentialRepository.new,
                                               transaction: Repositories::Shared::Transaction.new, policy: manage_content)
    end

    def update_exercise
      UseCases::Assessment::UpdateExercise.new(exercises:, transaction: Repositories::Shared::Transaction.new, policy: manage_content)
    end

    def publish_exercise = UseCases::Assessment::PublishExercise.new(**transition_dependencies)
    def archive_exercise = UseCases::Assessment::ArchiveExercise.new(**transition_dependencies)

    def transition_dependencies
      { exercises:, audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
        policy: manage_content, clock: Time.zone }
    end

    def manage_content = Policies::Catalog::ManageContentPolicy.new
  end
end

# 🌐 DELIVERY · Identity::PendingSchoolJoinsController
# Rôle : « Rejoindre cet établissement » de l'écran d'attente : l'établissement choisi dans sa DRENA rattache l'enseignant
# ADR  : 0028, 0063, 0071, 0083, 0094 · UDR : 0050, 0056, 0079
module Identity
  class PendingSchoolJoinsController < AuthenticatedController
    include PendingAccountsController::SchoolChoice
    include JoinsSchool

    FIELDS = %i[drena_public_id school_public_id].freeze

    skip_before_action :hold_pending_teacher
    rate_limit to: 10, within: 1.minute, by: -> { request.remote_ip }, with: -> { refuse_too_many }

    SCREEN = "identity/pending_accounts/show".freeze

    # L'écran d'attente est celui de l'enseignant sans établissement : rattaché, il ajoute un établissement depuis
    # « Mes établissements » (ADR-0094, UDR-0099).
    def create
      return render_forbidden if current_actor.school_id

      @form = @school_join = form_input
      result = join_school.call(actor: current_actor, dto: @school_join)
      prepare_screen
      render_result result, form: SCREEN, success: lambda { |school|
        redirect_to_home notice: t(".welcome", school: school.name), status: :see_other
      }
    end

    private

    # Sans DRENA choisie, la liste désactivée n'envoie rien : le DTO dit ce qui manque, pas un 400.
    def form_input
      Dtos::School::SchoolJoinInput.new(**params.permit(school_join: FIELDS).to_h.fetch(:school_join, {}).symbolize_keys)
    end

    # L'écran d'attente re-rendu : celui de l'enseignant sans établissement, sa demande refusée gardée au-dessus.
    def prepare_screen
      @case = :teacher
      @join_request = Queries::School::JoinRequestsQuery.new.status_for(teacher_id: current_actor.user_id)
      load_school_choice(@school_join.drena_public_id)
    end

    # Au-delà de 10 essais par minute : l'état d'erreur à la place du formulaire, rien n'est cherché.
    def refuse_too_many
      @rate_limited = true
      @school_join = Dtos::School::SchoolJoinInput.new
      prepare_screen
      render SCREEN, status: :too_many_requests
    end
  end
end

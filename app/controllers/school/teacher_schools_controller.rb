# 🌐 DELIVERY · School::TeacherSchoolsController
# Rôle : « Mes établissements » de l'enseignant : la liste, « Ajouter un établissement » (DRENA puis établissement) et « Quitter »
# ADR  : 0028, 0083, 0094 · UDR : 0098 (§3.1), 0099 (§3.1 à §3.3) · l'enseignant est celui de la session, jamais un paramètre
module School
  class TeacherSchoolsController < AuthenticatedController
    include Identity::PendingAccountsController::SchoolChoice
    include JoinsSchool

    FIELDS = %i[drena_public_id school_public_id].freeze

    allow_roles :teacher
    rate_limit to: 10, within: 1.minute, only: :create, by: -> { request.remote_ip }, with: -> { refuse_too_many }

    # Sans JavaScript, la DRENA choisie revient ici en GET (formulaire school-join-drena) et liste ses établissements.
    def index
      @school_join = Dtos::School::SchoolJoinInput.new(
        drena_public_id: params.permit(school_join: :drena_public_id).dig(:school_join, :drena_public_id)
      )
      load_school_choice(@school_join.drena_public_id)
    end

    # UDR-0099 §3.2 : rattaché, la session passe sur le nouvel établissement ; il y choisit ses classes.
    def create
      @form = @school_join = form_input
      result = join_school.call(actor: current_actor, dto: @school_join, session_id: current_session.id)
      load_school_choice(@school_join.drena_public_id)
      render_result as_form_error(result), form: :index, success: lambda { |school|
        redirect_to teacher_classrooms_path, notice: t(".joined", school: school.name), status: :see_other
      }
    end

    # UDR-0099 §3.3 : la confirmation est dans la modale ; le dernier établissement n'a pas de menu.
    def destroy
      result = leave.call(actor: current_actor, school_public_id: params[:public_id].to_s)
      if result.success?
        redirect_to teacher_schools_path, notice: t(".left", school: result.value.school.name), status: :see_other
      elsif result.code == :forbidden && result.errors.present?
        redirect_to teacher_schools_path, alert: t(".last_school"), status: :see_other
      else
        render_error_page(result.code)
      end
    end

    private

    # Le plafond refusé par la policy se dit dans le formulaire, comme celui constaté sous verrou (UDR-0099 §3.2).
    def as_form_error(result)
      result.code == :forbidden && result.errors.present? ? Shared::Result.failure(:conflict, errors: result.errors) : result
    end

    # Sans DRENA choisie, la liste désactivée n'envoie rien : le DTO dit ce qui manque, pas un 400.
    def form_input
      Dtos::School::SchoolJoinInput.new(**params.permit(school_join: FIELDS).to_h.fetch(:school_join, {}).symbolize_keys)
    end

    def refuse_too_many
      @rate_limited = true
      @school_join = Dtos::School::SchoolJoinInput.new
      load_school_choice(nil)
      render :index, status: :too_many_requests
    end

    def leave
      UseCases::School::LeaveSchool.new(
        schools: Repositories::School::SchoolRepository.new, teachings: Repositories::Classroom::TeachingRepository.new,
        assignments: Repositories::Classroom::AssignmentRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        policy: Policies::School::LeaveSchoolPolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end

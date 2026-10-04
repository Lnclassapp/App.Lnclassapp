# 🌐 DELIVERY · SchoolAdmin::TeacherReinstatementsController
# Rôle : « Réintégrer » un enseignant retiré, sans confirmation ; la ligne part de « Enseignants retirés » sans rechargement
# ADR  : 0028, 0071 · UDR : 0056 · l'établissement est celui du compte, jamais un paramètre
module SchoolAdmin
  class TeacherReinstatementsController < BaseController
    # Un rattachement refusé par la base (il a rejoint ailleurs entre-temps) : il n'est plus à réintégrer, 404.
    REFUSALS = { forbidden: :forbidden }.freeze

    def create
      result = reinstate.call(actor: current_actor, school_id: current_actor.school_id, teacher_public_id: params[:public_id].to_s)
      return refuse(REFUSALS.fetch(result.code, :not_found)) if result.failure?

      @teacher = result.value
      @notice = t(".done", name: @teacher.display_name)
      respond_to do |format|
        format.turbo_stream { @overview = Queries::School::DepartedTeachersQuery.new.call(school_id: current_actor.school_id) }
        format.html { redirect_to school_admin_departed_teachers_path, notice: @notice, status: :see_other }
      end
    end

    private

    # Turbo Stream : un toast au motif de la direction (UDR-0056 §3.0) ; HTML : les pages 403 et 404 communes.
    def refuse(code)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: helpers.turbo_stream_toast(t("school_admin.shared.errors.#{code}"), type: :error), status: code }
        format.html { render_error_page(code) }
      end
    end

    def reinstate
      UseCases::School::ReinstateTeacher.new(
        users: Repositories::Identity::UserRepository.new, schools: Repositories::School::SchoolRepository.new,
        departures: Repositories::School::TeacherDepartureRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        policy: Policies::School::ManageSchoolTeachersPolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end

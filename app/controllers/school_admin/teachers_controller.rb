# 🌐 DELIVERY · SchoolAdmin::TeachersController
# Rôle : « Enseignants » de la direction et leur retrait (DetachTeacher) ; l'établissement est celui du compte, jamais un paramètre
# ADR  : 0065, 0071 · UDR : 0052, 0056
module SchoolAdmin
  class TeachersController < BaseController
    def index
      @overview = teachers_query.call(school_id: current_actor.school_id)
      # Gestes affichés sur un établissement actif seulement, le serveur refuse de toute façon (UDR-0056 §2.6) ; BaseController
      # a déjà refusé une direction sans établissement.
      @manageable = Queries::School::OwnSchoolQuery.new.call(school_id: current_actor.school_id).active?
    end

    def destroy
      result = detach_teacher.call(actor: current_actor, school_id: current_actor.school_id, teacher_public_id: params[:public_id])
      return refuse(result.code) if result.failure?

      @detached = result.value
      @notice = t(".detached", name: @detached.teacher.display_name, count: @detached.assignments_archived)
      respond_to do |format|
        format.turbo_stream { @last_removed = teachers_query.call(school_id: current_actor.school_id).teachers.empty? }
        format.html { redirect_to school_admin_teachers_path, notice: @notice, status: :see_other }
      end
    end

    private

    # UDR-0056 §3.0 : en Turbo Stream, le toast porte le motif de la direction ; en HTML, les pages 403 et 404 communes.
    def refuse(code)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: helpers.turbo_stream_toast(t("school_admin.shared.errors.#{code}"), type: :error), status: code
        end
        format.html { render_error_page(code) }
      end
    end

    def teachers_query = Queries::School::SchoolTeachersQuery.new

    def detach_teacher
      UseCases::School::DetachTeacher.new(
        schools: Repositories::School::SchoolRepository.new, users: Repositories::Identity::UserRepository.new,
        teachings: Repositories::Classroom::TeachingRepository.new, assignments: Repositories::Classroom::AssignmentRepository.new,
        departures: Repositories::School::TeacherDepartureRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        policy: Policies::School::ManageSchoolTeachersPolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end

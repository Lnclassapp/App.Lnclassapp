# 🌐 DELIVERY · SchoolAdmin::TeachersController
# Rôle : « Enseignants » de la direction, la confirmation de leur retrait (lue à la demande) et le retrait (DetachTeacher)
# ADR  : 0065, 0067, 0071 · UDR : 0006, 0052, 0056 · l'établissement est celui du compte, jamais un paramètre
module SchoolAdmin
  class TeachersController < BaseController
    def index
      @overview = teachers_query.call(school_id: current_actor.school_id)
      # Gestes affichés sur un établissement actif seulement, le serveur refuse de toute façon (UDR-0056 §2.6) ; BaseController
      # a déjà refusé une direction sans établissement.
      @manageable = Queries::School::OwnSchoolQuery.new.call(school_id: current_actor.school_id).active?
    end

    # UDR-0056, amendement du 2026-10-04 : la confirmation n'est plus copiée dans chaque ligne, elle arrive dans le frame
    # « modal » ; sans frame, la même adresse est une page complète. La policy du retrait passe avant toute lecture.
    def removal
      allowed = manage_teachers.call(actor: current_actor, school: schools.find_by_id(id: current_actor.school_id))
      render_result allowed, success: lambda { |_|
        @teacher = teachers_query.teacher(school_id: current_actor.school_id, public_id: params[:public_id])
        render_not_found if @teacher.nil?
      }
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
    def schools = Repositories::School::SchoolRepository.new
    def manage_teachers = Policies::School::ManageSchoolTeachersPolicy.new

    def detach_teacher
      UseCases::School::DetachTeacher.new(
        schools:, users: Repositories::Identity::UserRepository.new,
        teachings: Repositories::Classroom::TeachingRepository.new, assignments: Repositories::Classroom::AssignmentRepository.new,
        departures: Repositories::School::TeacherDepartureRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        policy: manage_teachers, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end

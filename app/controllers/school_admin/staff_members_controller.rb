# 🌐 DELIVERY · SchoolAdmin::StaffMembersController
# Rôle : la direction retire une autre direction de son établissement (ArchiveSchoolStaff) ; 403 et 404 en toast
# ADR  : 0065, 0071, 0077 · UDR : 0006, 0070 (§3.4) · :public_id est celui du compte retiré
module SchoolAdmin
  class StaffMembersController < BaseController
    def destroy
      result = archive_school_staff.call(actor: current_actor, target_public_id: params[:public_id])
      return refuse(result.code) if result.failure?

      @archived = result.value
      @notice = t("shared.school_staff.done", name: @archived.user.display_name)
      respond_to do |format|
        format.turbo_stream { @by_code_count = Queries::School::SchoolStaffQuery.new.by_code_count(school_id: current_actor.school_id) }
        format.html { redirect_to school_admin_school_path, notice: @notice, status: :see_other }
      end
    end

    private

    # Même mécanique que TeachersController#destroy (UDR-0056 §3.0), avec les motifs du bloc « Direction » (UDR-0070 §3.4).
    def refuse(code)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: helpers.turbo_stream_toast(t("shared.school_staff.#{code}"), type: :error), status: code
        end
        format.html { render_error_page(code) }
      end
    end

    def archive_school_staff
      UseCases::School::ArchiveSchoolStaff.new(
        staff: Repositories::School::StaffRepository.new, schools: Repositories::School::SchoolRepository.new,
        users: Repositories::Identity::UserRepository.new, sessions: Repositories::Identity::SessionRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, policy: Policies::School::RemoveSchoolStaffPolicy.new,
        transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end

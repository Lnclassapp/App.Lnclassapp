# 🌐 DELIVERY · Teams::SchoolStaffMembersController
# Rôle : l'équipe retire une direction depuis la fiche de son établissement (ArchiveSchoolStaff) ; 403 et 404 en toast
# ADR  : 0028, 0071, 0077 (§4.3) · UDR : 0006, 0070 (§3.0, §3.4, §3.5) · :public_id est celui du compte retiré
module Teams
  class SchoolStaffMembersController < BaseController
    include SchoolStaffBlock

    before_action :load_target

    def destroy
      result = archive_school_staff.call(actor: current_actor, target_public_id: @target.user_public_id)
      return refuse(result.code) if result.failure?

      @archived = result.value
      @notice = t("shared.school_staff.done", name: @archived.user.display_name)
      respond_to do |format|
        format.turbo_stream { load_school_staff(@school) }
        format.html { redirect_to school_path(@school.public_id), notice: @notice, status: :see_other }
      end
    end

    private

    # La cible doit être une direction de l'établissement de l'URL : sinon, 404, comme un compte inconnu.
    def load_target
      @school = Repositories::School::SchoolRepository.new.find_by_public_id(public_id: params[:school_public_id])
      @target = @school && Repositories::School::StaffRepository.new.find_by_public_id(public_id: params[:public_id])
      refuse(:not_found) unless @target && @target.school_id == @school.id
    end

    # Même mécanique que SchoolAdmin::StaffMembersController, avec les motifs du bloc « Direction » (UDR-0070 §3.4).
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

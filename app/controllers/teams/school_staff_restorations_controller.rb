# 🌐 DELIVERY · Teams::SchoolStaffRestorationsController
# Rôle : l'équipe admin ou field restaure une direction retirée depuis la fiche (RestoreSchoolStaff) ; 409 (plafond, chef), 403, 404
# ADR  : 0028, 0071, 0077 (§4.2, §4.3), 0092 · UDR : 0006, 0070 (§3.0, §3.5), 0092 (§3.4) · :staff_member_public_id du compte restauré
module Teams
  class SchoolStaffRestorationsController < BaseController
    include SchoolStaffBlock

    before_action :load_target

    def create
      result = restore_school_staff.call(actor: current_actor, target_public_id: @target.user_public_id)
      return refuse(result.code, reason: Array(result.errors[:base]).first) if result.failure?

      @restored = result.value
      @notice = t(".done", name: @restored.user.display_name)
      respond_to do |format|
        format.turbo_stream { load_school_staff(@school) }
        format.html { redirect_to school_path(@school.public_id), notice: @notice, status: :see_other }
      end
    end

    private

    # La cible doit être une direction de l'établissement de l'URL : sinon, 404, comme un compte inconnu.
    def load_target
      @school = Repositories::School::SchoolRepository.new.find_by_public_id(public_id: params[:school_public_id])
      @target = @school && Repositories::School::StaffRepository.new.find_by_public_id(public_id: params[:staff_member_public_id])
      refuse(:not_found) unless @target && @target.school_id == @school.id
    end

    # 409 : le plafond des arrivées par le code (UDR-0070 §3.5) ou un autre chef actif (UDR-0092 §3.4) ; 403 et 404 : les
    # motifs du bloc « Direction ».
    def refuse(code, reason: nil)
      message = code == :conflict ? t(".#{reason == :head_taken ? "head_taken" : "cap_reached"}") : t("shared.school_staff.#{code}")
      respond_to do |format|
        format.turbo_stream { render turbo_stream: helpers.turbo_stream_toast(message, type: :error), status: code }
        format.html { code == :conflict ? redirect_to(school_path(@school.public_id), alert: message, status: :see_other) : render_error_page(code) }
      end
    end

    def restore_school_staff
      UseCases::School::RestoreSchoolStaff.new(
        staff: Repositories::School::StaffRepository.new, users: Repositories::Identity::UserRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, policy: Policies::School::RestoreSchoolStaffPolicy.new,
        transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end

# 🌐 DELIVERY · Teams::SchoolStaffPositionsController
# Rôle : l'équipe admin ou field change la fonction d'une direction depuis la fiche (SetStaffPosition) ; modale à la demande
# ADR  : 0028, 0092 (§4.3) · UDR : 0052, 0092 (§3.4) · :staff_member_public_id est celui du compte ; 403 avant toute lecture
module Teams
  class SchoolStaffPositionsController < BaseController
    include SchoolStaffBlock

    # La règle avant la cible : un membre qui ne peut pas changer une fonction reçoit 403, que la direction existe ou non.
    before_action :authorize_change
    before_action :load_target

    # Servie dans le frame « modal » depuis le menu ⋮ de la ligne ; sans frame, page complète.
    def edit
      @form = Dtos::School::StaffPositionInput.new(position: @target.position)
    end

    def update
      @form = Dtos::School::StaffPositionInput.new(position: params.expect(staff_position: [ :position ])[:position])
      render_result set_staff_position.call(actor: current_actor, target_public_id: @target.user_public_id, dto: @form),
                    form: :edit, success: lambda { |changed|
                      @notice = t(".done", name: changed.user.display_name)
                      respond_to do |format|
                        format.turbo_stream { load_school_staff(@school) }
                        format.html { redirect_to school_path(@school.public_id), notice: @notice, status: :see_other }
                      end
                    }
    end

    private

    def authorize_change
      render_forbidden if policy.call(actor: current_actor).failure?
    end

    # La cible doit être une direction active de l'établissement de l'URL : sinon, 404, comme un compte inconnu.
    def load_target
      @school = Repositories::School::SchoolRepository.new.find_by_public_id(public_id: params[:school_public_id])
      @target = @school && Repositories::School::StaffRepository.new.find_by_public_id(public_id: params[:staff_member_public_id])
      @user = @target && Repositories::Identity::UserRepository.new.find(id: @target.user_id)
      render_not_found unless @target && @target.school_id == @school.id && !@target.archived?
    end

    def policy = Policies::School::SetStaffPositionPolicy.new

    def set_staff_position
      UseCases::School::SetStaffPosition.new(
        staff: Repositories::School::StaffRepository.new, users: Repositories::Identity::UserRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, policy:, transaction: Repositories::Shared::Transaction.new,
        clock: Time.zone
      )
    end
  end
end

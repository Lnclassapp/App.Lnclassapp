# 🌐 DELIVERY · Teams::StaffInvitationsController
# Rôle : l'équipe invite la direction d'un établissement en modale, depuis sa fiche ; le lien s'affiche une fois, dans la modale
# ADR  : 0026, 0028, 0038, 0065 · UDR : 0019, 0052
module Teams
  class StaffInvitationsController < BaseController
    before_action :authorize_invitation, only: :new
    before_action :load_school

    def new
      @form = Dtos::Identity::SchoolStaffInvitationInput.new(school_public_id: @school.public_id)
    end

    # Succès : toast, la modale montre le lien ; repli HTML : la page `created`. Le lien ne doit rester dans aucun cache.
    def create
      @form = form_input
      render_result invite.call(actor: current_actor, dto: @form), form: :new, success: lambda { |invited|
        @invitation = invited.invitation
        @invitation_url = invitation_url(invited.token)
        response.headers["Cache-Control"] = "no-store"
        respond_to do |format|
          format.turbo_stream
          format.html { render :created, status: :created }
        end
      }
    end

    private

    def authorize_invitation
      render_forbidden if policy.call(actor: current_actor).failure?
    end

    def load_school
      @school = Queries::School::SchoolsQuery.new.find(public_id: params[:school_public_id])
      render_not_found if @school.nil?
    end

    def form_input
      Dtos::Identity::SchoolStaffInvitationInput.new(school_public_id: @school.public_id, contact: params.expect(invitation: [ :contact ])[:contact])
    end

    def policy = Policies::Identity::InviteSchoolStaffPolicy.new

    def invite
      UseCases::Identity::InviteSchoolStaff.new(
        invitations: Repositories::Identity::InvitationRepository.new, users: Repositories::Identity::UserRepository.new,
        schools: Repositories::School::SchoolRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, policy:, digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end

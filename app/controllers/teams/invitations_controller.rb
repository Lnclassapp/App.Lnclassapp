# 🌐 DELIVERY · Teams::InvitationsController
# Rôle : un admin de l'équipe invite un membre en modale ; le lien s'affiche une fois dans la modale, jamais dans un flash
# ADR  : 0026, 0028, 0038 · UDR : 0006, 0019
module Teams
  class InvitationsController < BaseController
    before_action :authorize_invitation, only: :new

    def new
      @form = Dtos::Identity::TeamInvitationInput.new
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

    def form_input = Dtos::Identity::TeamInvitationInput.new(params.expect(invitation: %i[contact team_role]))

    def policy = Policies::Identity::InviteTeamPolicy.new

    def invite
      UseCases::Identity::InviteTeamMember.new(
        invitations: Repositories::Identity::InvitationRepository.new, users: Repositories::Identity::UserRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
        policy:, digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end

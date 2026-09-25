# 🌐 DELIVERY · Identity::InvitationsController
# Rôle : la personne invitée ouvre son lien et crée son compte team ; lien inconnu 404, périmé ou déjà servi refusé
# ADR  : 0026, 0028, 0031, 0038, 0050 · UDR : 0019
module Identity
  class InvitationsController < ApplicationController
    FIELDS = %i[last_name first_name gender pin pin_confirmation].freeze

    allow_unauthenticated_access
    rate_limit to: 5, within: 1.minute, by: -> { request.remote_ip }, with: -> { render_rate_limited(:show) }

    def show
      @form = Dtos::Identity::InvitationAcceptanceInput.new
      result = acceptance.check(token: params[:token])
      return render_expired(:gone) if result.code == :expired

      render_result result, success: ->(_invitation) { render :show }
    end

    # Le compte n'a pas encore de second facteur : aucune session n'est ouverte, il l'enrôle à sa première connexion.
    def accept
      @form = form_input
      result = acceptance.call(token: params[:token], dto: @form)
      return render_expired(:unprocessable_entity) if result.code == :expired

      render_result result, form: :show, success: lambda { |_user|
        redirect_to new_session_path, notice: t(".accepted"), status: :see_other
      }
    end

    private

    def render_expired(status)
      @expired = true
      render :show, status:
    end

    # Sans paramètres (lecture du lien limitée en débit), un formulaire vide.
    def form_input = Dtos::Identity::InvitationAcceptanceInput.new(params.fetch(:invitation, {}).permit(*FIELDS))

    def acceptance
      UseCases::Identity::AcceptInvitation.new(
        invitations: Repositories::Identity::InvitationRepository.new,
        registrations: Repositories::Identity::RegistrationRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
        digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end

# 🌐 DELIVERY · Identity::InvitationsController
# Rôle : la personne invitée ouvre son lien et crée son compte team ou direction ; lien inconnu 404, périmé ou déjà servi refusé
# ADR  : 0026, 0028, 0031, 0038, 0050, 0065 · UDR : 0019, 0052
module Identity
  class InvitationsController < ApplicationController
    FIELDS = %i[last_name first_name gender pin pin_confirmation].freeze

    allow_unauthenticated_access
    helper_method :invitation_school_name
    rate_limit to: 5, within: 1.minute, by: -> { request.remote_ip }, with: -> { render_rate_limited(:show) }

    def show
      @form = Dtos::Identity::InvitationAcceptanceInput.new
      result = acceptance.check(token: params[:token])
      return render_expired(:gone) if result.code == :expired

      render_result result, success: ->(_invitation) { render :show }
    end

    # Aucune session n'est ouverte : un compte team enrôle son second facteur à sa première connexion, une direction
    # se connecte par numéro et PIN (ADR-0065).
    def accept
      @form = form_input
      result = acceptance.call(token: params[:token], dto: @form)
      return render_expired(:unprocessable_entity) if result.code == :expired

      render_result result, form: :show, success: lambda { |user|
        redirect_to new_session_path, notice: t(user.role == "school_admin" ? ".accepted_school_admin" : ".accepted"), status: :see_other
      }
    end

    private

    # Invitation de direction : l'établissement qu'elle rejoint (UDR-0052) ; nil pour l'équipe ou un lien inconnu.
    def invitation_school_name
      Array(acceptance.check(token: params[:token]).value).filter_map(&:school_id)
                                                          .map { Repositories::School::SchoolRepository.new.find_by_id(id: it).name }.first
    end

    def render_expired(status)
      @expired = true
      render :show, status:
    end

    # Sans paramètres (lecture du lien limitée en débit), un formulaire vide.
    def form_input = Dtos::Identity::InvitationAcceptanceInput.new(params.fetch(:invitation, {}).permit(*FIELDS))

    def acceptance
      UseCases::Identity::AcceptInvitation.new(
        invitations: Repositories::Identity::InvitationRepository.new,
        registrations: Repositories::Identity::RegistrationRepository.new, staffs: Repositories::School::StaffRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
        digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end

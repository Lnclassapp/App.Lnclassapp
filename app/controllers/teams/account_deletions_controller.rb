# 🌐 DELIVERY · Teams::AccountDeletionsController
# Rôle : l'équipe traite la demande de suppression d'un compte élève, en modale depuis sa fiche : date de la demande, puis anonymisation
# ADR  : 0026, 0028, 0036 (§4) · UDR : 0006, 0020, 0054
module Teams
  class AccountDeletionsController < BaseController
    # La règle avant le compte : `allow_roles :team` du parent refuse en 403 qui n'est pas de l'équipe, comme la policy
    # (cible nil), que le compte existe ou non ; le use case la rejoue à l'envoi.
    before_action :load_account

    def new
      @form = Dtos::Identity::DeletionRequestInput.new
    end

    # Succès : toast, modale refermée, la fiche remplacée par « Compte supprimé » ; repli HTML : retour à la recherche.
    def create
      @form = Dtos::Identity::DeletionRequestInput.new(params.expect(account_deletion: [ :requested_on ]))
      render_result anonymize.call(actor: current_actor, target_public_id: @account.public_id, dto: @form), form: :new,
                                                                                                          success: lambda { |done|
        @deleted = done
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to teams_account_lookup_path, notice: t(".notice"), status: :see_other }
        end
      }
    end

    private

    # Un compte inconnu, déjà anonymisé ou qui n'est pas un élève n'a pas de demande à traiter ici.
    def load_account
      @account = users.find_by_public_id(public_id: params[:user_public_id])
      render_not_found unless @account&.student? && !@account.anonymized?
    end

    def users = (@users ||= Repositories::Identity::UserRepository.new)
    def policy = Policies::Identity::DeleteUserPolicy.new

    def anonymize
      UseCases::Identity::AnonymizeUser.new(
        users:, sessions: Repositories::Identity::SessionRepository.new,
        second_factors: Repositories::Identity::SecondFactorRepository.new,
        pin_recoveries: Repositories::Identity::PinRecoveryRepository.new,
        memberships: Repositories::Classroom::MembershipRepository.new, photos: Repositories::Identity::ProfilePhotoStore.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
        policy:, clock: Time.zone
      )
    end
  end
end

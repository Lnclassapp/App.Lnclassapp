# 🌐 DELIVERY · Teams::AccountDeletionsController
# Rôle : l'équipe traite la demande de suppression d'un élève, en modale depuis sa fiche : date (reprise si enregistrée), puis anonymisation
# ADR  : 0026, 0028, 0036 (§4, amendement 2) · UDR : 0006, 0020, 0054
module Teams
  class AccountDeletionsController < BaseController
    # La règle avant le compte : un membre qui n'est pas `admin` reçoit 403, que le compte existe ou non (ADR-0038).
    before_action { render_forbidden if policy.call(actor: current_actor).failure? }
    before_action :load_account

    # ADR-0036, amendement 2 : la date de la demande enregistrée à sa réception, s'il y en a une, est reprise.
    def new
      @form = Dtos::Identity::DeletionRequestInput.new(requested_on: deletion_requests.pending_for(user_id: @account.id)&.requested_on)
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
    def deletion_requests = (@deletion_requests ||= Repositories::Identity::DeletionRequestRepository.new)

    def anonymize
      UseCases::Identity::AnonymizeUser.new(
        users:, sessions: Repositories::Identity::SessionRepository.new,
        second_factors: Repositories::Identity::SecondFactorRepository.new,
        pin_recoveries: Repositories::Identity::PinRecoveryRepository.new,
        login_attempts: Repositories::Identity::LoginAttemptRepository.new,
        memberships: Repositories::Classroom::MembershipRepository.new, photos: Repositories::Identity::ProfilePhotoStore.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
        policy:, clock: Time.zone, deletion_requests:
      )
    end
  end
end

# 🌐 DELIVERY · Teams::DeletionRequestsController
# Rôle : demandes de suppression : la liste en attente par échéance ; enregistrer (modale) ou annuler depuis la fiche du compte
# ADR  : 0026, 0028, 0036 (amendement 2 du 2026-10-02), 0038 · UDR : 0006, 0020, 0054, 0057, 0062
module Teams
  class DeletionRequestsController < BaseController
    # Le bloc de la fiche du compte (teams/account_lookups/_result), chargé dans ce frame et remplacé après chaque geste.
    BLOCK_FRAME = "account_deletion_request".freeze

    # La règle avant le compte : un membre qui n'est pas `admin` reçoit 403, que le compte existe ou non (ADR-0038).
    before_action { render_forbidden if policy.call(actor: current_actor).failure? }
    before_action :load_account, except: :index

    def index
      @requests = Queries::Identity::PendingDeletionRequestsQuery.new.call
    end

    def show
      @request = deletion_requests.pending_for(user_id: @account.id)
    end

    def new
      @form = Dtos::Identity::DeletionRequestInput.new
    end

    # Succès : toast, modale refermée, le bloc de la fiche dit « Demande reçue le … » ; repli HTML : retour à la fiche.
    def create
      @form = Dtos::Identity::DeletionRequestInput.new(params.expect(deletion_request: [ :requested_on ]))
      render_result record.call(actor: current_actor, target_public_id: @account.public_id, dto: @form), form: :new,
                                                                                                       success: lambda { |request|
        @request = request
        respond_with_block
      }
    end

    def destroy
      render_result cancel.call(actor: current_actor, target_public_id: @account.public_id), success: ->(_) { respond_with_block }
    end

    private

    # Un compte inconnu, déjà anonymisé ou qui n'est pas un élève n'a pas de demande de suppression (ADR-0036 §4).
    def load_account
      @account = users.find_by_public_id(public_id: params[:user_public_id])
      render_not_found unless @account&.student? && !@account.anonymized?
    end

    def respond_with_block
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to teams_account_lookup_path(contact: @account.contact), notice: t(".notice"), status: :see_other }
      end
    end

    def users = (@users ||= Repositories::Identity::UserRepository.new)
    def deletion_requests = (@deletion_requests ||= Repositories::Identity::DeletionRequestRepository.new)
    def policy = Policies::Identity::DeleteUserPolicy.new

    def dependencies
      { users:, deletion_requests:, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, policy:, clock: Time.zone }
    end

    def record = UseCases::Identity::RecordDeletionRequest.new(**dependencies)
    def cancel = UseCases::Identity::CancelDeletionRequest.new(**dependencies)
  end
end

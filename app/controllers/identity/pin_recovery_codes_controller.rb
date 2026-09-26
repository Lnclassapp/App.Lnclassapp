# 🌐 DELIVERY · Identity::PinRecoveryCodesController
# Rôle : l'enseignant ou l'équipe génère un code de récupération du PIN ; le code s'affiche une fois dans une modale, jamais dans un flash
# ADR  : 0026, 0028, 0032, 0050 · UDR : 0006, 0020
module Identity
  class PinRecoveryCodesController < AuthenticatedController
    allow_roles :team, :teacher
    # Par compte émetteur, pas par adresse : une salle des professeurs partage souvent la même adresse IP.
    rate_limit to: 10, within: 1.minute, only: :create, by: -> { current_actor.user_id }, with: -> { render_too_many_requests }

    # Succès : toast, la modale du code ; repli HTML : la page `show`. Le code ne doit rester dans aucun cache.
    def create
      render_result issue.call(actor: current_actor, target_public_id: params[:user_public_id]), success: lambda { |issued|
        @issued = issued
        response.headers["Cache-Control"] = "no-store"
        respond_to do |format|
          format.turbo_stream
          format.html { render :show, status: :created }
        end
      }
    end

    private

    def render_too_many_requests
      message = t("errors.codes.rate_limited")
      respond_to do |format|
        format.turbo_stream { render turbo_stream: helpers.turbo_stream_toast(message, type: :error), status: :too_many_requests }
        format.html { render plain: message, status: :too_many_requests }
      end
    end

    def issue
      UseCases::Identity::IssuePinRecoveryCode.new(
        users: Repositories::Identity::UserRepository.new, memberships: Repositories::Classroom::MembershipRepository.new,
        teachings: Repositories::Classroom::TeachingRepository.new, pin_recoveries: Repositories::Identity::PinRecoveryRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
        policy: Policies::Identity::IssuePinRecoveryCodePolicy.new, digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end

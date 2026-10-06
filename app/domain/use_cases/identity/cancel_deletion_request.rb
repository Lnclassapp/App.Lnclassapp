# 🧠 DOMAINE · UseCases::Identity::CancelDeletionRequest
# Rôle : l'élève ou son parent se rétracte : l'équipe `admin` annule la demande en attente, au journal ; le compte reste
# ADR  : 0026, 0028, 0036 (amendement 2 du 2026-10-02), 0038
module UseCases
  module Identity
    class CancelDeletionRequest
      def initialize(users:, deletion_requests:, audit_log:, transaction:, policy:, clock:)
        @users = users
        @deletion_requests = deletion_requests
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → success(Entities::Identity::DeletionRequest annulée) | :forbidden | :not_found (compte inconnu, aucune demande en attente)
      def call(actor:, target_public_id:)
        target = @users.find_by_public_id(public_id: target_public_id)
        return Shared::Result.failure(:not_found) if target.nil?

        allowed = @policy.call(actor:, target:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:not_found) if @deletion_requests.pending_for(user_id: target.id).nil?

        now = @clock.now
        @transaction.call { cancel(actor, target, now) }
      end

      private

      # Une annulation ou un traitement concurrent a déjà clos la demande : rien à annuler, rien au journal.
      def cancel(actor, target, now)
        closed = @deletion_requests.close(user_id: target.id, status: Entities::Identity::DeletionRequest::CANCELLED,
                                          closed_by_id: actor.user_id, at: now)
        return Shared::Result.failure(:not_found) if closed.nil?

        @audit_log.record(action: "user.deletion_request_cancelled", actor_id: actor.user_id, at: now, subject_type: "User",
                          subject_id: target.id, metadata: { requested_on: closed.requested_on.iso8601 })
        Shared::Result.success(closed)
      end
    end
  end
end

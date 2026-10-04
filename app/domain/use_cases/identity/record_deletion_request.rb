# 🧠 DOMAINE · UseCases::Identity::RecordDeletionRequest
# Rôle : l'équipe `admin` enregistre une demande de suppression à sa réception : datée, une seule en attente, au journal
# ADR  : 0026, 0028, 0036 (amendement 2 du 2026-10-02), 0038
module UseCases
  module Identity
    class RecordDeletionRequest
      ALREADY_ANONYMIZED = { base: [ :already_anonymized ] }.freeze
      ALREADY_PENDING = { base: [ :already_pending ] }.freeze
      IN_FUTURE = { requested_on: [ :in_future ] }.freeze

      def initialize(users:, deletion_requests:, audit_log:, transaction:, policy:, clock:)
        @users = users
        @deletion_requests = deletion_requests
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Identity::DeletionRequestInput (date de réception).
      # → success(Entities::Identity::DeletionRequest) | :forbidden | :not_found | :conflict (anonymisé, déjà en attente)
      #   | :invalid (date absente ou future)
      def call(actor:, target_public_id:, dto:)
        target = @users.find_by_public_id(public_id: target_public_id)
        return Shared::Result.failure(:not_found) if target.nil?

        allowed = @policy.call(actor:, target:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:conflict, errors: ALREADY_ANONYMIZED) if target.anonymized?

        now = @clock.now
        invalid = invalid_request(dto, now.to_date)
        return invalid if invalid
        return Shared::Result.failure(:conflict, errors: ALREADY_PENDING) if @deletion_requests.pending_for(user_id: target.id)

        @transaction.call { record(actor, target, dto.requested_on, now) }
      end

      private

      def invalid_request(dto, today)
        return Shared::Result.failure(:invalid, errors: dto.errors.details.transform_values { it.pluck(:error) }) unless dto.valid?

        Shared::Result.failure(:invalid, errors: IN_FUTURE) if dto.requested_on > today
      end

      def record(actor, target, requested_on, now)
        recorded = @deletion_requests.record(user_id: target.id, requested_on:, recorded_by_id: actor.user_id, at: now)
        return recorded if recorded.failure?

        @audit_log.record(action: "user.deletion_requested", actor_id: actor.user_id, at: now, subject_type: "User",
                          subject_id: target.id, metadata: { requested_on: requested_on.iso8601 })
        recorded
      end
    end
  end
end

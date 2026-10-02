# 🔌 INFRA · Repositories::Identity::DeletionRequestRepository
# Rôle : demandes de suppression : une seule en attente par compte (index partiel), close par un UPDATE … WHERE pending
# ADR  : 0027, 0036 (amendement 2 du 2026-10-02)
module Repositories
  module Identity
    class DeletionRequestRepository
      include Ports::Identity::DeletionRequestRepositoryPort

      PENDING = Entities::Identity::DeletionRequest::PENDING
      ALREADY_PENDING = { base: [ :already_pending ] }.freeze
      COLUMNS = %i[id user_id requested_on status].freeze

      def pending_for(user_id:)
        values = Orm::AccountDeletionRequest.where(user_id:, status: PENDING).pick(*COLUMNS)
        values && Entities::Identity::DeletionRequest.new(*values)
      end

      # Savepoint : une demande déjà en attente (index unique partiel) devient :conflict sans casser la transaction englobante.
      def record(user_id:, requested_on:, recorded_by_id:, at:)
        record = Orm::AccountDeletionRequest.transaction(requires_new: true) do
          Orm::AccountDeletionRequest.create!(user_id:, requested_on:, recorded_by_id:, status: PENDING, created_at: at,
                                              updated_at: at)
        end
        ::Shared::Result.success(Entities::Identity::DeletionRequest.new(id: record.id, user_id:, requested_on: record.requested_on,
                                                                         status: PENDING))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: ALREADY_PENDING)
      end

      # La ligne en attente est verrouillée (FOR UPDATE) jusqu'à la fin de la transaction du use case : une clôture
      # concurrente attend, puis ne la trouve plus en attente.
      def close(user_id:, status:, closed_by_id:, at:)
        values = Orm::AccountDeletionRequest.where(user_id:, status: PENDING).lock.pick(*COLUMNS)
        return if values.nil?

        Orm::AccountDeletionRequest.where(id: values.first).update_all(status:, closed_at: at, closed_by_id:, updated_at: at)
        Entities::Identity::DeletionRequest.new(*values).with(status:)
      end
    end
  end
end

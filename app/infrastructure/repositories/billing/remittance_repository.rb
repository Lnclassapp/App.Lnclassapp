# 🔌 INFRA · Repositories::Billing::RemittanceRepository
# Rôle : traduit Orm::Billing::Remittance en entité ; ajout seul, un versement ne se modifie ni ne se supprime
# ADR  : 0126 (contexte billing, §4.1 et §4.7)
module Repositories
  module Billing
    class RemittanceRepository
      include Ports::Billing::RemittanceRepositoryPort

      def record(relay_point_id:, amount_xof:, received_at:, reference:, reason:, recorded_by_id:)
        return ::Shared::Result.failure(:invalid, errors: { relay_point_id: [ :blank ] }) unless Orm::Billing::RelayPoint.exists?(relay_point_id)
        return ::Shared::Result.failure(:invalid, errors: { amount_xof: [ :other_than ] }) if amount_xof.to_i.zero?

        record = Orm::Billing::Remittance.create!(relay_point_id:, amount_xof:, received_at:, reference:, reason:, recorded_by_id:)
        ::Shared::Result.success(map(record))
      end

      def for_relay_point(relay_point_id:)
        Orm::Billing::Remittance.where(relay_point_id:).order(received_at: :desc, id: :desc).map { map(it) }
      end

      private

      def map(record)
        Entities::Billing::Remittance.new(id: record.id, public_id: record.public_id, relay_point_id: record.relay_point_id,
                                          amount_xof: record.amount_xof, received_at: record.received_at, reference: record.reference,
                                          reason: record.reason, recorded_by_id: record.recorded_by_id, created_at: record.created_at)
      end
    end
  end
end

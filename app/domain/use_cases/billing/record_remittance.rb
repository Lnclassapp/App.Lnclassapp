# 🧠 DOMAINE · UseCases::Billing::RecordRemittance
# Rôle : l'équipe saisit le versement d'un point relais ; une erreur se corrige par un versement négatif avec motif, jamais par une modification
# ADR  : cartes-activation (contexte billing, §4.1 et §4.7)
module UseCases
  module Billing
    class RecordRemittance
      def initialize(remittances:, audit_log:, transaction:, policy:, clock:)
        @remittances = remittances
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Billing::RemittanceInput. → Result(Entities::Billing::Remittance) | :forbidden | :invalid
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        @transaction.call { store(actor, dto) }
      end

      private

      def store(actor, dto)
        at = @clock.now
        recorded = @remittances.record(relay_point_id: dto.relay_point_id, amount_xof: dto.amount, received_at: dto.received_at || at,
                                       reference: dto.reference, reason: dto.reason, recorded_by_id: actor.user_id)
        return recorded if recorded.failure?

        remittance = recorded.value
        @audit_log.record(action: "billing.remittance_recorded", actor_id: actor.user_id, at:, subject_type: "Remittance",
                          subject_id: remittance.id,
                          metadata: { relay_point_id: remittance.relay_point_id, amount_xof: remittance.amount_xof,
                                      reference: remittance.reference, reason: remittance.reason })
        recorded
      end
    end
  end
end

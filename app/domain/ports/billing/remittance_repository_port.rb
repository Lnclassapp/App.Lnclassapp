# 🧠 DOMAINE · Ports::Billing::RemittanceRepositoryPort
# Rôle : contrat des versements des points relais, écrits une fois, jamais modifiés ni supprimés
# ADR  : cartes-activation (contexte billing, §4.1)
module Ports
  module Billing
    module RemittanceRepositoryPort
      # → Result(Entities::Billing::Remittance)
      def record(relay_point_id:, amount_xof:, received_at:, reference:, reason:, recorded_by_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #record"
      end

      # Du plus récent au plus ancien. → [Entities::Billing::Remittance]
      def for_relay_point(relay_point_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #for_relay_point"
      end
    end
  end
end

# 🧠 DOMAINE · Ports::Identity::AuditLogPort
# Rôle : contrat du journal d'audit, sans aucun secret dans les métadonnées
# ADR  : 0050, 0080
module Ports
  module Identity
    module AuditLogPort
      # action ∈ Entities::Identity::AuditAction::ALL, sinon ArgumentError. → true
      def record(action:, actor_id:, at:, subject_type: nil, subject_id: nil, metadata: {}, ip: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #record"
      end

      # ADR-0080 : vide l'IP des événements créés strictement avant `at`, par lots de `batch_size` ; l'événement reste.
      # → Integer (nombre d'événements traités)
      def erase_ips_before(at:, batch_size:)
        raise NotImplementedError, "#{self.class} doit implémenter #erase_ips_before"
      end
    end
  end
end

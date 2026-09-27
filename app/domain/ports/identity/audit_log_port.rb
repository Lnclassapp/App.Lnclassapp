# 🧠 DOMAINE · Ports::Identity::AuditLogPort
# Rôle : contrat du journal d'audit, sans aucun secret dans les métadonnées
# ADR  : 0050
module Ports
  module Identity
    module AuditLogPort
      # action ∈ Entities::Identity::AuditAction::ALL, sinon ArgumentError. → true
      def record(action:, actor_id:, at:, subject_type: nil, subject_id: nil, metadata: {}, ip: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #record"
      end
    end
  end
end

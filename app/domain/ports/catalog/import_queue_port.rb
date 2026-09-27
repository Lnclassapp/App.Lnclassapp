# 🧠 DOMAINE · Ports::Catalog::ImportQueuePort
# Rôle : contrat de mise en file du job d'import d'un type, résolu à l'appel
# ADR  : 0039, 0052
module Ports
  module Catalog
    module ImportQueuePort
      # → true
      def enqueue(kind:, report_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #enqueue"
      end
    end
  end
end

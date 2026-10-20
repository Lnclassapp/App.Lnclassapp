# 🧠 DOMAINE · Ports::Catalog::ImportQueuePort
# Rôle : contrat de mise en file du job d'import d'un type, résolu à l'appel
# ADR  : 0039, 0052, 0096
module Ports
  module Catalog
    module ImportQueuePort
      # → Boolean (false : la file a refusé le job, rien ne le fera tourner)
      def enqueue(kind:, report_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #enqueue"
      end
    end
  end
end

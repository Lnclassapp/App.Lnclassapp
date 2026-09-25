# 🧠 DOMAINE · Ports::Catalog::ImportFileStorePort
# Rôle : contrat du stockage du fichier importé, jamais sur le disque local
# ADR  : 0039, 0047
module Ports
  module Catalog
    module ImportFileStorePort
      # → true
      def attach(report_id:, io:, filename:)
        raise NotImplementedError, "#{self.class} doit implémenter #attach"
      end

      # → String (contenu JSON brut)
      def read(report_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #read"
      end
    end
  end
end

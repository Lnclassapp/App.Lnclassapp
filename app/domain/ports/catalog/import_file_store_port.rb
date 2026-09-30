# 🧠 DOMAINE · Ports::Catalog::ImportFileStorePort
# Rôle : contrat du stockage des fichiers importés, dans l'ordre d'envoi, jamais sur le disque local
# ADR  : 0039, 0047, 0068
module Ports
  module Catalog
    module ImportFileStorePort
      # files : objets qui répondent à io et filename, dans l'ordre d'envoi. → true
      def attach(report_id:, files:)
        raise NotImplementedError, "#{self.class} doit implémenter #attach"
      end

      # → [Entities::Catalog::ImportFile], dans l'ordre d'envoi (contenu JSON brut, en UTF-8)
      def read(report_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #read"
      end
    end
  end
end

# 🧠 DOMAINE · Ports::Catalog::ImportSchemaPort
# Rôle : contrat de validation d'un document par son schéma JSON versionné
# ADR  : 0039
module Ports
  module Catalog
    module ImportSchemaPort
      # Schéma config/schemas/<format>.v<version>.json. → [Entities::Catalog::ImportError] (code schema, chemin JSON)
      def validate(format:, version:, document:)
        raise NotImplementedError, "#{self.class} doit implémenter #validate"
      end
    end
  end
end

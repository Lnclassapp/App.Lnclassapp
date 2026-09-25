# 🧠 DOMAINE · UseCases::Catalog::Importer
# Rôle : contrat d'un adaptateur d'import, que RunImport pilote ; chaque adaptateur définit KIND et référence sa policy
# ADR  : 0028, 0039
module UseCases
  module Catalog
    module Importer
      # Cible de l'enveloppe (DRENA, cours, fiche) résolue par son slug. → Result(target | nil) | failure(:not_found)
      def resolve_target(document:)
        raise NotImplementedError, "#{self.class} doit implémenter #resolve_target"
      end

      # Référentiels et clés existantes, chargés une fois. → Entities::Catalog::ImportContext
      def prepare(target:)
        raise NotImplementedError, "#{self.class} doit implémenter #prepare"
      end

      # N'écrit rien. → Entities::Catalog::ImportItem
      def validate_root(root:, path:, context:)
        raise NotImplementedError, "#{self.class} doit implémenter #validate_root"
      end

      # Appelé dans une transaction ; lève si la base refuse. → { imported: Integer, details: Hash }
      def write(items:, author_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #write"
      end
    end
  end
end

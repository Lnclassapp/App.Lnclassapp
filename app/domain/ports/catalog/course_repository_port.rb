# 🧠 DOMAINE · Ports::Catalog::CourseRepositoryPort
# Rôle : contrat de persistance des cours, un seul agrégat pour lire et écrire
# ADR  : 0029, 0035, 0039
module Ports
  module Catalog
    module CourseRepositoryPort
      # Tous statuts. → Entities::Catalog::Course | nil
      def find_by_slug(slug:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_slug"
      end

      # → Result(Course) | failure(:conflict, errors: { name: [:taken] })
      def create(course:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # → Result(Course) | failure(:conflict, errors: { name: [:taken] })
      def update(course:)
        raise NotImplementedError, "#{self.class} doit implémenter #update"
      end

      # Pose published_at (première publication) ou archived_at. → true
      def transition(id:, to:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #transition"
      end

      # Clés de doublon de l'import. → Set[[NameKey.call(name), level_id, material_id, series_id]]
      def existing_keys
        raise NotImplementedError, "#{self.class} doit implémenter #existing_keys"
      end
    end
  end
end

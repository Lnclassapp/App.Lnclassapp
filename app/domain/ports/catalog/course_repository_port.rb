# 🧠 DOMAINE · Ports::Catalog::CourseRepositoryPort
# Rôle : contrat de persistance des cours, un seul agrégat pour lire et écrire
# ADR  : 0029, 0035, 0039, 0075
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

      # Clés de doublon de l'import. → Set[[Entities::Shared::NaturalKey.compact(name), level_id, material_id, series_id]]
      def existing_keys
        raise NotImplementedError, "#{self.class} doit implémenter #existing_keys"
      end

      # Slugs déjà pris, pour les calculer avant une insertion en masse (Entities::Catalog::Slug). → Set[String]
      def taken_slugs
        raise NotImplementedError, "#{self.class} doit implémenter #taken_slugs"
      end

      # ADR-0075 : une entrée par classe où un exercice d'une fiche du cours est assigné (assignation active).
      # → Array<[level_id, series_id]> (series_id de la classe, nil si elle n'en a pas)
      def assigned_classroom_levels(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #assigned_classroom_levels"
      end
    end
  end
end

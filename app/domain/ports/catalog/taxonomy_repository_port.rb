# 🧠 DOMAINE · Ports::Catalog::TaxonomyRepositoryPort
# Rôle : contrat du référentiel (niveaux, séries, liaisons, matières), géré par l'équipe
# ADR  : 0029, 0034, 0036
module Ports
  module Catalog
    module TaxonomyRepositoryPort
      # → [Entities::Catalog::Level], triés par position
      def levels
        raise NotImplementedError, "#{self.class} doit implémenter #levels"
      end

      # → [Entities::Catalog::Series], triées par nom
      def series
        raise NotImplementedError, "#{self.class} doit implémenter #series"
      end

      # → [Entities::Catalog::Material], triées par nom
      def materials
        raise NotImplementedError, "#{self.class} doit implémenter #materials"
      end

      # → Entities::Catalog::Level | nil
      def find_level(slug:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_level"
      end

      # → Entities::Catalog::Series | nil
      def find_series(slug:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_series"
      end

      # → Entities::Catalog::Material | nil
      def find_material(slug:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_material"
      end

      # Slug dérivé du nom puis figé. → Result(Level) | failure(:conflict, errors: { <champ>: [:taken] })
      def create_level(level:)
        raise NotImplementedError, "#{self.class} doit implémenter #create_level"
      end

      # Le slug ne change jamais. → Result(Level) | failure(:conflict, errors: { <champ>: [:taken] })
      def update_level(level:)
        raise NotImplementedError, "#{self.class} doit implémenter #update_level"
      end

      # → Result | failure(:conflict, errors: { base: [:referenced] })
      def delete_level(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete_level"
      end

      # → Result(Series) | failure(:conflict, errors: { name: [:taken] })
      def create_series(series:)
        raise NotImplementedError, "#{self.class} doit implémenter #create_series"
      end

      # → Result(Series) | failure(:conflict, errors: { name: [:taken] })
      def update_series(series:)
        raise NotImplementedError, "#{self.class} doit implémenter #update_series"
      end

      # → Result | failure(:conflict, errors: { base: [:referenced] })
      def delete_series(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete_series"
      end

      # → Result(Material) | failure(:conflict, errors: { <champ>: [:taken] })
      def create_material(material:)
        raise NotImplementedError, "#{self.class} doit implémenter #create_material"
      end

      # → Result(Material) | failure(:conflict, errors: { <champ>: [:taken] })
      def update_material(material:)
        raise NotImplementedError, "#{self.class} doit implémenter #update_material"
      end

      # → Result | failure(:conflict, errors: { base: [:referenced] })
      def delete_material(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete_material"
      end

      # → Result | failure(:conflict, errors: { base: [:already_linked] })
      def link(level_id:, series_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #link"
      end

      # Refusé tant qu'une classe ou un cours utilise le couple. → Result | failure(:conflict, errors: { base: [:referenced] })
      def unlink(level_id:, series_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #unlink"
      end

      # → Entities::Catalog::TaxonomyLookup
      def lookup
        raise NotImplementedError, "#{self.class} doit implémenter #lookup"
      end
    end
  end
end

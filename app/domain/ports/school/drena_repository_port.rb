# 🧠 DOMAINE · Ports::School::DrenaRepositoryPort
# Rôle : contrat des DRENA, créées à l'écran ou importées ; slug figé préfixé drena-
# ADR  : 0034, 0036, 0055
module Ports
  module School
    module DrenaRepositoryPort
      # → [Entities::School::Drena], triées par nom
      def all
        raise NotImplementedError, "#{self.class} doit implémenter #all"
      end

      # → Entities::School::Drena | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # Cible d'un import d'écoles. → Entities::School::Drena | nil
      def find_by_slug(slug:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_slug"
      end

      # Slug dérivé du nom à la création. → Result(Drena) | failure(:conflict, errors: { name: [:taken] })
      def create(drena:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # Le slug reste figé. → Result(Drena) | failure(:conflict, errors: { name: [:taken] })
      def update(drena:)
        raise NotImplementedError, "#{self.class} doit implémenter #update"
      end

      # → Result | failure(:conflict, errors: { base: [:has_schools] })
      def delete(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete"
      end

      # Résolution des imports d'écoles. → { "drena-abidjan-1" => 12, … } (clé = slug)
      def ids_by_slug
        raise NotImplementedError, "#{self.class} doit implémenter #ids_by_slug"
      end

      # Noms pris, tels qu'en base (unicité exacte de l'index). → Set[String]
      def taken_names
        raise NotImplementedError, "#{self.class} doit implémenter #taken_names"
      end

      # Import : lignes { public_id:, name:, slug: } calculées avant l'insertion, sans rappel ORM. → Integer (lignes écrites)
      def insert_many(rows:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #insert_many"
      end
    end
  end
end

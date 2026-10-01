# 🧠 DOMAINE · Ports::Catalog::EssentialRepositoryPort
# Rôle : contrat de persistance des fiches essentielles d'un cours
# ADR  : 0029, 0035, 0039
module Ports
  module Catalog
    module EssentialRepositoryPort
      # Tous statuts, avec course_status. → Entities::Catalog::Essential | nil
      def find_by_slug(slug:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_slug"
      end

      # position = max + 1. → Result(Essential) | failure(:conflict, errors: { name: [:taken] })
      def create(essential:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # → Result(Essential) | failure(:conflict, errors: { name: [:taken] })
      def update(essential:)
        raise NotImplementedError, "#{self.class} doit implémenter #update"
      end

      # → true
      def transition(id:, to:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #transition"
      end

      # Clés de doublon de l'import, pour les cours donnés ou tous. → Set[[course_id, Entities::Shared::NaturalKey.normalize(name)]]
      def existing_keys(course_ids: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #existing_keys"
      end

      # → Integer
      def next_position(course_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #next_position"
      end

      # → Set[String]
      def taken_slugs
        raise NotImplementedError, "#{self.class} doit implémenter #taken_slugs"
      end

      # Publication en cascade : slugs des fiches brouillon du cours, dans l'ordre du cours. → [String]
      def draft_slugs(course_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #draft_slugs"
      end
    end
  end
end

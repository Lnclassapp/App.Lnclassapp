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

      # Verrouille la ligne jusqu'à la fin de la transaction en cours (publication contre modification). → true
      def lock(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #lock"
      end

      # → true
      def transition(id:, to:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #transition"
      end

      # Clés de doublon de l'import, pour les cours donnés ou tous. → Set[[course_id, Entities::Shared::NaturalKey.normalize(name)]]
      def existing_keys(course_ids: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #existing_keys"
      end

      # Les notions d'une leçon par nom normalisé. → { Entities::Shared::NaturalKey.normalize(name) => id }
      def ids_by_name(course_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #ids_by_name"
      end

      # Les noms des notions d'une leçon tels qu'écrits, dans l'ordre de la leçon (ids_by_name confond ceux qui se normalisent pareil). → [String]
      def names(course_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #names"
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

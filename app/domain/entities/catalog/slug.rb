# 🧠 DOMAINE · Entities::Catalog::Slug
# Rôle : slug unique précalculé pour les écritures en masse, même règle que le slug figé de l'ORM
# ADR  : 0029, 0039
module Entities
  module Catalog
    module Slug
      # taken : Set des slugs déjà pris, complété par le slug renvoyé.
      def self.unique(base_name, taken:)
        base = base_name.to_s.parameterize
        candidate = base
        suffix = 1
        candidate = "#{base}-#{suffix += 1}" while taken.include?(candidate)
        taken << candidate
        candidate
      end
    end
  end
end

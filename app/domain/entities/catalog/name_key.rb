# 🧠 DOMAINE · Entities::Catalog::NameKey
# Rôle : clé de doublon d'un nom importé : squish, minuscules, sans accents
# ADR  : 0039
module Entities
  module Catalog
    module NameKey
      def self.call(name) = ActiveSupport::Inflector.transliterate(name.to_s.squish).downcase
    end
  end
end

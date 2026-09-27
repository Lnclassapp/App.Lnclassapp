# 🧠 DOMAINE · Entities::Shared::NaturalKey
# Rôle : clé de doublon d'un nom importé : squish, minuscules, sans accents
# ADR  : 0039
module Entities
  module Shared
    module NaturalKey
      def self.normalize(text) = ActiveSupport::Inflector.transliterate(text.to_s.squish).downcase

      # Clé d'un nom de cours : ni la casse, ni les accents, ni les espaces ne distinguent deux cours (décision du porteur).
      def self.compact(text) = normalize(text).delete(" ")
    end
  end
end

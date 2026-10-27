# 🧠 DOMAINE · Entities::Catalog::NumericAnswer
# Rôle : réponse numérique attendue d'un exercice de fiche de cours ; lit la saisie de l'élève (virgule, point, espaces, fraction a/b) et la juge à ±0,011
# ADR  : 0110-fiche-de-cours-en-donnees-importees (chantier contenu-en-blocs) · même règle que parseNumber/isNumericCorrect de generators/bank.js
module Entities
  module Catalog
    class NumericAnswer
      TOLERANCE = 0.011
      NUMBER = /\A[+-]?(?:\d+\.?\d*|\.\d+)\z/

      attr_reader :expected

      def self.parse(input)
        text = input.to_s.gsub(/[[:space:]]/, "").tr("−", "-").tr(",", ".")
        return nil if text.empty?

        parts = text.split("/", -1)
        return nil if parts.size > 2 || parts.any? { !NUMBER.match?(it) }

        numerator, denominator = parts.map { Float(it) }
        return numerator if denominator.nil?

        denominator.zero? ? nil : numerator / denominator
      end

      # Deux décimales au plus, virgule française : 3.6 -> "3,6", 3.0 -> "3".
      def self.format(value)
        rounded = value.to_f.round(2)
        rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s.tr(".", ",")
      end

      def initialize(expected)
        raise ArgumentError, "expected must be a finite number" unless expected.is_a?(Numeric) && expected.to_f.finite?

        @expected = expected.to_f
      end

      # :incomplete (champ vide), :correct ou :wrong (dont une saisie illisible).
      def verdict(input)
        return :incomplete if input.to_s.strip.empty?

        correct?(input) ? :correct : :wrong
      end

      def correct?(input)
        value = self.class.parse(input)
        !value.nil? && (value - expected).abs < TOLERANCE
      end
    end
  end
end

# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::Numeric
# Rôle : réponse en nombre : juste si l'écart à la valeur attendue ne dépasse pas la marge (0 sans marge) ; illisible, mal formée
# ADR  : 0091 (§4.2 : une seule valeur attendue, numeric_tolerance ; §4.3)
require "bigdecimal"

module Entities
  module Assessment
    module QuestionKinds
      class Numeric
        INPUT = :response_text
        INVALID = { response_text: [ :not_a_number ] }.freeze
        NUMBER = /\A-?\d+(?:\.\d+)?\z/
        # Espace, insécable et fine insécable entre deux chiffres : séparateurs des milliers (« 1 000 »).
        THOUSANDS = /(?<=\d)[   ](?=\d)/

        # Borne de la colonne questions.numeric_tolerance, decimal(12, 4).
        TOLERANCE_MAX = BigDecimal("99999999.9999")
        TOLERANCE_SCALE = 4
        EDGE_SPACES = /\A[[:space:]]+|[[:space:]]+\z/

        # « 3,5 », « 3.5 », « −2 » (moins Unicode), « 1 000 » → BigDecimal ; toute autre saisie → nil. Le point et la virgule
        # sont toujours le séparateur décimal : « 1.000 » vaut 1 (ADR-0091 §4.3). Les espaces des bords, insécables compris, tombent.
        def self.parse(text)
          normalized = text.to_s.gsub(EDGE_SPACES, "").tr("\u2212", "-").gsub(THOUSANDS, "").tr(",", ".")
          BigDecimal(normalized) if normalized.match?(NUMBER)
        end

        def self.structure_errors(answers:, numeric_tolerance:, **)
          errors = []
          errors << :numeric_needs_one_value unless answers.size == 1
          errors << :numeric_value_unreadable if answers.size == 1 && parse(answers.first.content).nil?
          errors << :negative_tolerance if numeric_tolerance&.negative?
          errors << :tolerance_out_of_range if numeric_tolerance && !tolerance_in_range?(numeric_tolerance)
          errors
        end

        # Fini, au plus 99 999 999,9999, et sans plus de quatre décimales : ce que la colonne garde sans l'arrondir.
        def self.tolerance_in_range?(tolerance)
          tolerance.finite? && tolerance <= TOLERANCE_MAX && tolerance.round(TOLERANCE_SCALE) == tolerance
        end

        # Une saisie illisible n'est pas une mauvaise réponse : l'élève voit une erreur de saisie (422).
        def self.well_formed?(_question, text) = !parse(text).nil?

        def self.correct?(question, text)
          (parse(text) - parse(question.answers.first.content)).abs <= (question.numeric_tolerance || 0)
        end
      end
    end
  end
end

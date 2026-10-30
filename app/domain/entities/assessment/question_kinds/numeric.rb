# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::Numeric
# Rôle : réponse en nombre : juste si l'écart à la valeur attendue ne dépasse pas la marge (0 sans marge) ; illisible, mal formée
# ADR  : 0091 (§4.2 : une seule valeur attendue, numeric_tolerance ; §4.3), 0115
require "bigdecimal"

module Entities
  module Assessment
    module QuestionKinds
      class Numeric
        AUTO_GRADED = true
        INPUT = :response_text
        INVALID = { response_text: [ :not_a_number ] }.freeze
        NUMBER = /\A-?\d+(?:\.\d+)?\z/
        # Espace, insécable et fine insécable entre deux chiffres : séparateurs des milliers (« 1 000 »).
        THOUSANDS = /(?<=\d)[   ](?=\d)/

        # Borne de la colonne questions.numeric_tolerance, decimal(12, 4).
        TOLERANCE_MAX = BigDecimal("99999999.9999")
        TOLERANCE_SCALE = 4
        EDGE_SPACES = /\A[[:space:]]+|[[:space:]]+\z/
        # ADR-0115 : l'unité d'une réponse, 10 caractères au plus, sans chiffre, signe ni séparateur décimal : elle ne peut pas
        # manger un chiffre de la réponse (unité « 0 » et réponse « 40 » pour 4).
        UNIT_MAX = 10
        UNIT_FORBIDDEN = /[\d,.+\-\u2212]/

        # « 3,5 », « 3.5 », « −2 » (moins Unicode), « 1 000 » → BigDecimal ; toute autre saisie → nil. Le point et la virgule
        # sont toujours le séparateur décimal : « 1.000 » vaut 1 (ADR-0091 §4.3). Les espaces des bords, insécables compris, tombent.
        def self.parse(text)
          normalized = text.to_s.gsub(EDGE_SPACES, "").tr("\u2212", "-").gsub(THOUSANDS, "").tr(",", ".")
          BigDecimal(normalized) if normalized.match?(NUMBER)
        end

        # La réponse de l'élève sans l'unité de la question, si elle finit par elle (« 4,8 cm » → « 4,8 », espaces compris).
        # Comparaison de texte, jamais de motif : l'unité n'entre dans aucune expression régulière. Sans unité, le texte tel quel.
        def self.without_unit(text, unit)
          given = text.to_s.gsub(EDGE_SPACES, "")
          wanted = unit.to_s.strip
          # Une unité refusée à la structure (« 0 », « , ») ne retire rien : elle ne mange jamais un chiffre de la réponse.
          return text if wanted.empty? || wanted.match?(UNIT_FORBIDDEN) || !given.end_with?(wanted)

          given.delete_suffix(wanted)
        end

        # Le nombre que dit la réponse de l'élève, unité de la question retirée → BigDecimal | nil
        def self.read(question, text) = parse(without_unit(text, question.unit))

        def self.structure_errors(answers:, numeric_tolerance:, unit: nil, **)
          errors = unit_errors(unit)
          errors << :numeric_needs_one_value unless answers.size == 1
          errors << :numeric_value_unreadable if answers.size == 1 && parse(answers.first.content).nil?
          errors << :negative_tolerance if numeric_tolerance&.negative?
          errors << :tolerance_out_of_range if numeric_tolerance && !tolerance_in_range?(numeric_tolerance)
          errors
        end

        def self.unit_errors(unit)
          wanted = unit.to_s.strip
          errors = []
          errors << :unit_too_long if wanted.length > UNIT_MAX
          errors << :unit_invalid if wanted.match?(UNIT_FORBIDDEN)
          errors
        end

        # Fini, au plus 99 999 999,9999, et sans plus de quatre décimales : ce que la colonne garde sans l'arrondir.
        def self.tolerance_in_range?(tolerance)
          tolerance.finite? && tolerance <= TOLERANCE_MAX && tolerance.round(TOLERANCE_SCALE) == tolerance
        end

        # Une saisie illisible n'est pas une mauvaise réponse : l'élève voit une erreur de saisie (422).
        def self.well_formed?(question, text) = !read(question, text).nil?

        def self.correct?(question, text)
          (read(question, text) - parse(question.answers.first.content)).abs <= (question.numeric_tolerance || 0)
        end
      end
    end
  end
end

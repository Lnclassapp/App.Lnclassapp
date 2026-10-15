# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::Numeric
# Rôle : réponse en nombre (ADR-0091 §4.3), notée au Lot E ; la lecture d'un nombre saisi sert déjà à la marge de l'équipe
# ADR  : 0091
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

        # « 3,5 », « 3.5 », « −2 » (moins Unicode), « 1 000 » → BigDecimal ; toute autre saisie → nil.
        def self.parse(text)
          normalized = text.to_s.strip.tr("−", "-").gsub(THOUSANDS, "").tr(",", ".")
          BigDecimal(normalized) if normalized.match?(NUMBER)
        end

        def self.structure_errors(**) = [ :not_available ]
        def self.well_formed?(_question, _response) = false
        def self.correct?(_question, _response) = false
      end
    end
  end
end

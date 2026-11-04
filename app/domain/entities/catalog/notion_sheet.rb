# 🧠 DOMAINE · Entities::Catalog::NotionSheet
# Rôle : la fiche au gabarit fixe d'une notion (À retenir · La méthode · Un exemple corrigé · Le piège à éviter) et ses règles de forme
# ADR  : 0116-fiche-de-revision-par-notion-et-figures-parametrees (§4.1, §6), 0119-entrainement-de-notion-corrige-sans-trace (§4 : practice) · UDR : 0141-fiche-de-revision-en-quatre-blocs
module Entities
  module Catalog
    # practice : l'entraînement facultatif de la notion (NotionPractice) | nil. Sa validation est celle de NotionPractice.errors_for.
    NotionSheet = Data.define(:remember, :method_steps, :example_statement, :example_steps, :pitfall, :figure_key, :practice) do
      def initialize(practice: nil, **) = super

      METHOD_STEPS = (2..8)
      TEXT_MAX = 1_200
      STEP_MAX = 300

      def self.from_raw(raw)
        new(remember: raw["remember"].to_s.strip, method_steps: Array(raw["method"]).map { it.to_s.strip },
            example_statement: raw.dig("example", "statement").to_s.strip, example_steps: Array(raw.dig("example", "steps")).map { it.to_s.strip },
            pitfall: raw["pitfall"].to_s.strip, figure_key: raw["figure"].presence,
            practice: NotionPractice.from_raw(raw["practice"]))
      end

      # → Array<[chemin, raison]> ; vide si la fiche est conforme. Ne lève jamais, quelle que soit la forme reçue.
      def self.errors_for(raw)
        errors = []
        errors.concat(text_errors("remember", raw["remember"], TEXT_MAX))
        errors.concat(text_errors("pitfall", raw["pitfall"], TEXT_MAX))
        steps = raw["method"].is_a?(Array) ? raw["method"] : []
        errors << [ "method", "invalid_count" ] unless METHOD_STEPS.cover?(steps.size)
        steps.each_with_index { |step, index| errors.concat(text_errors("method[#{index}]", step, STEP_MAX)) }
        example = raw["example"].is_a?(Hash) ? raw["example"] : {}
        errors.concat(text_errors("example.statement", example["statement"], TEXT_MAX))
        example_steps = example["steps"].is_a?(Array) ? example["steps"] : []
        errors << [ "example.steps", "example_steps_mismatch" ] unless example_steps.size == steps.size
        example_steps.each_with_index { |step, index| errors.concat(text_errors("example.steps[#{index}]", step, STEP_MAX)) }
        errors
      end

      def self.text_errors(path, value, max)
        return [ [ path, "blank" ] ] unless value.is_a?(String) && value.strip.present?

        value.length > max ? [ [ path, "too_long" ] ] : []
      end
    end
  end
end

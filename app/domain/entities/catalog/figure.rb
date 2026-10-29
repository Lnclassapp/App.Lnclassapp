# 🧠 DOMAINE · Entities::Catalog::Figure
# Rôle : une figure paramétrée d'une leçon (clé, sorte, description, paramètres bornés, 0 à 4 curseurs) et ses règles de forme
# ADR  : XXXX-fiche-de-revision-par-notion-et-figures-parametrees (§4.1, §4.2) · UDR : XXXX-fiche-de-revision-en-quatre-blocs (§3.3)
module Entities
  module Catalog
    Figure = Data.define(:key, :kind, :description, :params, :controls) do
      REASON = "figure_invalid".freeze

      def self.from_raw(raw)
        new(key: raw["key"], kind: raw["kind"], description: raw["description"], params: raw["params"] || {}, controls: Array(raw["controls"]))
      end

      # → Array<[chemin, "figure_invalid", { param: }]> ; vide si la figure est valide. Ne lève jamais, quelle que soit la forme reçue.
      def self.errors_for(raw)
        return [ violation("$", "$") ] unless raw.is_a?(Hash)

        errors = []
        errors << violation("key", "key") unless raw["key"].is_a?(String) && FigureKinds::KEY_PATTERN.match?(raw["key"])
        errors << violation("description", "description") unless FigureKinds::DESCRIPTION_LENGTH.cover?(raw["description"].to_s.length) && raw["description"].is_a?(String)
        if FigureKinds.known?(raw["kind"])
          errors.concat(params_errors(FigureKinds.fetch(raw["kind"]), raw["params"]))
        else
          errors << violation("kind", "kind")
        end
        errors.concat(controls_errors(raw["controls"], raw))
      end

      def self.violation(path, param) = [ path, REASON, { param: } ]

      def self.params_errors(kind, params)
        return [ violation("params", "params") ] unless params.is_a?(Hash)

        params.flat_map do |name, value|
          spec = kind.params[name]
          next [ violation("params.#{name}", name) ] unless spec

          param_errors(kind, name, spec, value)
        end
      end

      def self.param_errors(kind, name, spec, value)
        path = "params.#{name}"
        case spec.type
        when :number then number?(value) && spec.range.cover?(value) ? [] : [ violation(path, name) ]
        when :enum then spec.values.include?(value) ? [] : [ violation(path, name) ]
        else
          return [ violation(path, name) ] unless value.is_a?(Array) && value.size <= spec.max

          value.each_with_index.flat_map { |item, index| item_errors(kind.item_range, "#{path}[#{index}]", "#{name}[#{index}]", item) }
        end
      end

      def self.item_errors(range, path, param, item)
        case item
        when Numeric then range.cover?(item) ? [] : [ violation(path, param) ]
        when String then item.length <= FigureKinds::TEXT_MAX ? [] : [ violation(path, param) ]
        when Array
          return [ violation(path, param) ] if item.size > FigureKinds::ITEM_ARRAY_MAX

          item.each_with_index.flat_map { |value, index| scalar_errors(range, "#{path}[#{index}]", "#{param}[#{index}]", value) }
        when Hash then item.flat_map { |name, value| scalar_errors(range, "#{path}.#{name}", "#{param}.#{name}", value) }
        else [ violation(path, param) ]
        end
      end

      def self.scalar_errors(range, path, param, value)
        case value
        when Numeric then range.cover?(value) ? [] : [ violation(path, param) ]
        when String then value.length <= FigureKinds::TEXT_MAX ? [] : [ violation(path, param) ]
        when true, false then []
        else [ violation(path, param) ]
        end
      end

      def self.controls_errors(controls, raw)
        return [] if controls.nil?
        return [ violation("controls", "controls") ] unless controls.is_a?(Array) && controls.size <= FigureKinds::CONTROLS_MAX

        controls.each_with_index.flat_map { |control, index| control_errors(control, "controls[#{index}]", raw) }
      end

      def self.control_errors(control, path, raw)
        return [ violation(path, path) ] unless control.is_a?(Hash)

        bound = (-FigureKinds::CONTROL_BOUND..FigureKinds::CONTROL_BOUND)
        min, max, step = control.values_at("min", "max", "step")
        errors = []
        errors << violation("#{path}.param", "#{path}.param") unless control["param"].is_a?(String) && FigureKinds::PARAM_PATTERN.match?(control["param"]) && adjustable?(raw, control["param"])
        errors << violation("#{path}.min", "#{path}.min") unless number?(min) && bound.cover?(min)
        errors << violation("#{path}.max", "#{path}.max") unless number?(max) && bound.cover?(max) && (!number?(min) || max > min)
        errors << violation("#{path}.step", "#{path}.step") unless number?(step) && step.positive? && (!number?(min) || !number?(max) || max <= min || step <= max - min)
        label = control["label"]
        errors << violation("#{path}.label", "#{path}.label") unless label.is_a?(String) && (1..FigureKinds::LABEL_MAX).cover?(label.length)
        errors
      end

      # La clé est déclarée réglable par la sorte et présente dans `params` avec une valeur numérique.
      def self.adjustable?(raw, name)
        return true unless FigureKinds.known?(raw["kind"]) && raw["params"].is_a?(Hash)

        FigureKinds.fetch(raw["kind"]).adjustable.include?(name) && number?(raw["params"][name])
      end

      def self.number?(value) = value.is_a?(Numeric)
    end
  end
end

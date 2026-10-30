# 🧠 DOMAINE · Entities::Catalog::Figure
# Rôle : une figure paramétrée d'une leçon (clé, sorte, description, paramètres bornés, 0 à 4 curseurs) et ses règles de forme
# ADR  : 0116-fiche-de-revision-par-notion-et-figures-parametrees (§4.1, §4.2), 0117-figures-des-matieres-de-3eme (§4.2) · UDR : 0141-fiche-de-revision-en-quatre-blocs (§3.3)
# script/contenus/valider.rb ne charge que figure_kinds et figure (hors Zeitwerk) : figure.rb amène ses catalogues si personne ne l'a fait.
defined?(Entities::Catalog::FigureCatalogs) || require_relative("figure_catalogs")

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
          kind = FigureKinds.fetch(raw["kind"])
          errors.concat(params_errors(kind, raw["params"]))
          errors.concat(required_errors(kind, raw["params"]))
        else
          errors << violation("kind", "kind")
        end
        errors.concat(controls_errors(raw["controls"], raw)).uniq
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

      # Ce que le navigateur exige pour dessiner (lib/figures/<sorte>.js) : paramètres obligatoires puis cohérence entre eux.
      def self.required_errors(kind, params)
        return [] unless params.is_a?(Hash)

        missing = kind.required.call(params).reject { filled?(params[it]) || (EMPTY_LIST_OK.include?(it) && params[it].is_a?(Array)) }
        return missing.map { violation("params.#{it}", it) } if missing.any?
        return [] if oversized?(kind, params)

        send(:"#{kind.name}_errors", params)
      end

      # Une liste au-delà de sa borne est déjà refusée par params_errors : la cohérence n'est pas contrôlée (aucun coût quadratique sur une liste énorme).
      def self.oversized?(kind, params)
        kind.params.any? { |name, spec| spec.type == :list && params[name].is_a?(Array) && params[name].size > spec.max }
      end

      # Des paramètres obligatoires qui peuvent être une liste vide (molecule.js : un atome seul n'a aucune liaison).
      EMPTY_LIST_OK = %w[bonds].freeze

      def self.filled?(value) = value.is_a?(Array) ? value.any? : !value.nil?

      def self.geometry_errors(params)
        points = params["points"]
        return [] unless points.is_a?(Array)

        seen = Set.new
        points.each_with_index.flat_map do |point, index|
          path = "params.points[#{index}]"
          next [ violation(path, "points[#{index}]") ] unless point.is_a?(Hash)

          id = point["id"]
          duplicate = !seen.add?(id)
          bad = duplicate || !(id.is_a?(String) && !id.empty?)
          errors = bad ? [ violation("#{path}.id", "points[#{index}].id") ] : []
          %w[x y].each { |axis| errors << violation("#{path}.#{axis}", "points[#{index}].#{axis}") unless number?(point[axis]) }
          errors
        end
      end

      def self.coordinate_plane_errors(params)
        errors = []
        errors << violation("params.xmax", "xmax") unless !both_numbers?(params, "xmin", "xmax") || params["xmax"] > params["xmin"]
        errors << violation("params.ymax", "ymax") unless !both_numbers?(params, "ymin", "ymax") || params["ymax"] > params["ymin"]
        errors
      end

      def self.number_line_errors(params)
        return [] unless both_numbers?(params, "min", "max")
        return [ violation("params.max", "max") ] unless params["max"] > params["min"]

        too_many_ticks?(params["min"], params["max"], params["step"]) ? [ violation("params.step", "step") ] : []
      end

      # Plus de MAX_TICKS graduations entre deux bouts (sans division entière : 0..401 au pas 2 en fait 201).
      def self.too_many_ticks?(low, high, step) = number?(step) && step.positive? && (high - low) > FigureKinds::MAX_TICKS * step

      def self.stat_chart_errors(params)
        series = params["series"]
        return [] unless series.is_a?(Array)

        errors = series.each_with_index.reject { |value, _| number?(value) && value >= 0 }.map { |_, index| violation("params.series[#{index}]", "series[#{index}]") }
        errors << violation("params.series", "series") if errors.empty? && params["chart"] == "pie" && series.sum <= 0
        errors
      end

      def self.solid_errors(_params) = []

      # timeline.js : end > start, au plus 200 graduations ; événements et périodes dans [start, end].
      def self.timeline_errors(params)
        return [] unless both_numbers?(params, "start", "end")

        low = params["start"]
        high = params["end"]
        errors = []
        errors << violation("params.end", "end") unless high > low
        step = params["step"]
        errors << violation("params.step", "step") if high > low && too_many_ticks?(low, high, step)
        errors.concat(list_of(params, "events").each_with_index.flat_map { |event, index| event_errors(event, index, low..high) })
        errors.concat(list_of(params, "periods").each_with_index.flat_map { |period, index| period_errors(period, index, low..high) })
      end

      def self.event_errors(event, index, span)
        path = "params.events[#{index}]"
        return [ violation(path, "events[#{index}]") ] unless event.is_a?(Hash)

        errors = []
        errors << violation("#{path}.at", "events[#{index}].at") unless within?(event["at"], span)
        errors << violation("#{path}.label", "events[#{index}].label") unless text?(event["label"])
        errors
      end

      def self.period_errors(period, index, span)
        path = "params.periods[#{index}]"
        return [ violation(path, "periods[#{index}]") ] unless period.is_a?(Hash)

        errors = []
        errors << violation("#{path}.from", "periods[#{index}].from") unless within?(period["from"], span)
        errors << violation("#{path}.to", "periods[#{index}].to") unless within?(period["to"], span) && (!within?(period["from"], span) || period["to"] > period["from"])
        errors << violation("#{path}.label", "periods[#{index}].label") unless text?(period["label"])
        errors
      end

      # map : identifiants du fond `base` (FigureCatalogs), catégories de la légende ; rien à contrôler si le fond est inconnu (déjà refusé).
      def self.map_errors(params)
        base = params["base"]
        return [] unless FigureCatalogs::MAP_BASES.key?(base)

        legend = params["legend"].is_a?(Array) ? params["legend"].size : 0
        areas = list_of(params, "areas")
        errors = legend_errors(params)
        errors << violation("params.legend", "legend") if areas.any? && legend.zero?
        errors.concat(area_errors(areas, FigureCatalogs.areas(base), legend))
        errors.concat(place_errors(list_of(params, "places"), FigureCatalogs.places(base)))
        errors.concat(route_errors(list_of(params, "routes"), FigureCatalogs.places(base)))
      end

      def self.area_errors(areas, known, legend)
        seen = Set.new
        areas.each_with_index.flat_map do |area, index|
          path = "params.areas[#{index}]"
          next [ violation(path, "areas[#{index}]") ] unless area.is_a?(Hash)

          id = area["id"]
          errors = []
          errors << violation("#{path}.id", "areas[#{index}].id") unless seen.add?(id) && known.include?(id)
          errors << violation("#{path}.category", "areas[#{index}].category") unless legend.zero? || category?(area["category"], legend)
          errors
        end
      end

      def self.place_errors(places, known)
        places.each_with_index.flat_map do |place, index|
          path = "params.places[#{index}]"
          next [ violation(path, "places[#{index}]") ] unless place.is_a?(Hash)

          errors = []
          errors << violation("#{path}.id", "places[#{index}].id") unless known.include?(place["id"])
          errors.concat(label_errors(place, path, "places[#{index}]"))
        end
      end

      # Chaque entrée de la légende est un texte non vide.
      def self.legend_errors(params)
        return [] unless params["legend"].is_a?(Array)

        params["legend"].each_index.reject { text?(params["legend"][it]) }.map { violation("params.legend[#{it}]", "legend[#{it}]") }
      end

      def self.route_errors(routes, known)
        routes.each_with_index.flat_map do |route, index|
          path = "params.routes[#{index}]"
          next [ violation(path, "routes[#{index}]") ] unless route.is_a?(Hash)

          errors = %w[from to].reject { known.include?(route[it]) }.map { violation("#{path}.#{it}", "routes[#{index}].#{it}") }
          errors << violation("#{path}.to", "routes[#{index}].to") if errors.empty? && route["from"] == route["to"]
          errors.concat(label_errors(route, path, "routes[#{index}]"))
        end
      end

      # Un libellé facultatif : absent, ou un texte (la longueur est bornée par param_errors).
      def self.label_errors(item, path, param)
        item["label"].nil? || text?(item["label"]) ? [] : [ violation("#{path}.label", "#{param}.label") ]
      end

      # plate : parties de la planche (FigureCatalogs) ; une partie au plus une fois dans labels, et une fois dans highlight ; rien à contrôler si la planche est inconnue.
      def self.plate_errors(params)
        return [] unless FigureCatalogs::PLATES.key?(params["plate"])

        known = FigureCatalogs.parts(params["plate"])
        errors = label_part_errors(list_of(params, "labels"), known)
        highlight = list_of(params, "highlight")
        firsts = first_indexes(highlight) { it }
        errors.concat(highlight.each_index.reject { known.include?(highlight[it]) && firsts[highlight[it]] == it }.map { violation("params.highlight[#{it}]", "highlight[#{it}]") })
      end

      # → Hash { valeur => index de sa première apparition } ; le bloc donne la valeur d'un élément, nil pour l'ignorer.
      def self.first_indexes(list)
        list.each_with_index.with_object({}) do |(item, index), firsts|
          value = yield(item)
          firsts[value] ||= index unless value.nil?
        end
      end

      LABEL_KEYS = %w[part text].freeze

      def self.label_part_errors(labels, known)
        firsts = first_indexes(labels) { it["part"] if it.is_a?(Hash) }
        labels.each_with_index.flat_map do |label, index|
          path = "params.labels[#{index}]"
          next [ violation(path, "labels[#{index}]") ] unless label.is_a?(Hash) && (label.keys - LABEL_KEYS).empty?

          errors = []
          errors << violation("#{path}.part", "labels[#{index}].part") unless known.include?(label["part"]) && firsts[label["part"]] == index
          errors << violation("#{path}.text", "labels[#{index}].text") unless label["text"].nil? || text?(label["text"])
          errors
        end
      end

      # diagram : nœuds uniques, arêtes entre nœuds existants ; `tree` : une racine, un parent par nœud, pas de cycle ; `cycle` : 3 nœuds au moins.
      def self.diagram_errors(params)
        nodes = list_of(params, "nodes")
        legend = params["legend"].is_a?(Array) ? params["legend"].size : 0
        errors = legend_errors(params)
        firsts = first_indexes(nodes) { it["id"] if it.is_a?(Hash) }
        errors.concat(nodes.each_with_index.flat_map { |node, index| node_errors(node, index, firsts, legend) })
        errors.concat(edge_errors(list_of(params, "edges"), firsts.keys.select { text?(it) }.to_set))
        errors << violation("params.nodes", "nodes") if params["layout"] == "cycle" && nodes.size < 3
        errors.concat(tree_errors(params, nodes)) if errors.empty? && params["layout"] == "tree"
        errors
      end

      # `firsts` : l'index de la première apparition de chaque identifiant ; un doublon est refusé, sa première apparition gardée.
      def self.node_errors(node, index, firsts, legend)
        path = "params.nodes[#{index}]"
        return [ violation(path, "nodes[#{index}]") ] unless node.is_a?(Hash)

        errors = []
        errors << violation("#{path}.id", "nodes[#{index}].id") unless text?(node["id"]) && firsts[node["id"]] == index
        errors << violation("#{path}.label", "nodes[#{index}].label") unless text?(node["label"])
        errors << violation("#{path}.category", "nodes[#{index}].category") unless node["category"].nil? || category?(node["category"], legend)
        errors
      end

      def self.edge_errors(edges, ids)
        edges.each_with_index.flat_map do |edge, index|
          path = "params.edges[#{index}]"
          next [ violation(path, "edges[#{index}]") ] unless edge.is_a?(Hash)

          errors = %w[from to].reject { ids.include?(edge[it]) }.map { violation("#{path}.#{it}", "edges[#{index}].#{it}") }
          errors << violation("#{path}.to", "edges[#{index}].to") if errors.empty? && edge["from"] == edge["to"]
          errors.concat(label_errors(edge, path, "edges[#{index}]"))
        end
      end

      # Arbre : le premier parent d'un nœud gagne, l'arête en trop est refusée ; puis une seule racine et un chemin vers elle depuis chaque nœud.
      def self.tree_errors(params, nodes)
        ids = nodes.map { it["id"] }
        parents = {}
        errors = []
        list_of(params, "edges").each_with_index do |edge, index|
          errors << violation("params.edges[#{index}].to", "edges[#{index}].to") if parents.key?(edge["to"])
          parents[edge["to"]] ||= edge["from"]
        end
        return errors if errors.any?

        (ids - parents.keys).size == 1 && rooted?(ids, parents) ? [] : [ violation("params.edges", "edges") ]
      end

      # Remonter de parent en parent atteint-il une racine (aucun cycle) depuis chaque nœud ? Un nœud déjà reconnu arrête la remontée :
      # chaque nœud n'est parcouru qu'une fois en tout.
      def self.rooted?(ids, parents)
        rooted = Set.new
        ids.all? do |id|
          path = Set.new
          current = id
          until current.nil? || rooted.include?(current)
            return false unless path.add?(current)

            current = parents[current]
          end
          rooted.merge(path)
        end
      end

      # optics.js : la correction n'existe qu'en mode œil (le mode et les paramètres exigés sont déjà contrôlés par `required`).
      def self.optics_errors(params)
        return foreign_errors(params, OPTICS_LENS_KEYS) if params["mode"] == "eye"

        params["correction"].nil? ? [] : [ violation("params.correction", "correction") ]
      end

      OPTICS_LENS_KEYS = %w[focal object_distance object_height lens].freeze
      MOLECULE_ALKANE_KEYS = %w[carbons display].freeze
      MOLECULE_CUSTOM_KEYS = %w[atoms bonds].freeze

      # Les clés d'un autre mode n'ont aucun effet : on les refuse plutôt que de les laisser traîner.
      def self.foreign_errors(params, keys) = keys.select { params.key?(it) }.map { violation("params.#{it}", it) }

      # molecule.js : un alcane a un nombre entier de carbones ; un dessin libre a des atomes uniques sur la grille et des liaisons valides.
      def self.molecule_errors(params)
        if params["mode"] == "alkane"
          errors = params["carbons"].is_a?(Integer) ? [] : [ violation("params.carbons", "carbons") ]
          return errors + foreign_errors(params, MOLECULE_CUSTOM_KEYS)
        end

        return [] unless params["mode"] == "custom"

        atoms = list_of(params, "atoms")
        bonds = list_of(params, "bonds")

        firsts = {}
        atoms.each_with_index { |atom, index| firsts[atom["id"]] ||= index if atom.is_a?(Hash) }
        errors = atoms.each_with_index.flat_map { |atom, index| atom_errors(atom, index, firsts) }
        ids = firsts.keys.to_set
        seen = Set.new
        errors.concat(bonds.each_with_index.flat_map { |bond, index| bond_errors(bond, index, ids, seen) })
        errors.concat(valence_errors(atoms, bonds)) if errors.empty?
        errors.concat(foreign_errors(params, MOLECULE_ALKANE_KEYS))
      end

      def self.atom_errors(atom, index, firsts)
        path = "params.atoms[#{index}]"
        return [ violation(path, "atoms[#{index}]") ] unless atom.is_a?(Hash)

        errors = []
        errors << violation("#{path}.id", "atoms[#{index}].id") unless text?(atom["id"]) && firsts[atom["id"]] == index
        errors << violation("#{path}.element", "atoms[#{index}].element") unless FigureKinds::MOLECULE_ELEMENTS.include?(atom["element"])
        %w[x y].each { |axis| errors << violation("#{path}.#{axis}", "atoms[#{index}].#{axis}") unless atom[axis].is_a?(Integer) && FigureKinds::MOLECULE_GRID.cover?(atom[axis]) }
        errors
      end

      # `seen` : les paires d'atomes déjà reliées (dans un sens ou dans l'autre) ; une seconde liaison entre les mêmes atomes est refusée.
      def self.bond_errors(bond, index, ids, seen)
        path = "params.bonds[#{index}]"
        return [ violation(path, "bonds[#{index}]") ] unless bond.is_a?(Array) && bond.size == 3

        errors = (0..1).reject { ids.include?(bond[it]) }.map { violation("#{path}[#{it}]", "bonds[#{index}][#{it}]") }
        if errors.empty?
          if bond[0] == bond[1] then errors << violation("#{path}[1]", "bonds[#{index}][1]")
          elsif !seen.add?(Set[bond[0], bond[1]]) then errors << violation(path, "bonds[#{index}]")
          end
        end
        errors << violation("#{path}[2]", "bonds[#{index}][2]") unless bond[2].is_a?(Integer) && FigureKinds::BOND_ORDERS.cover?(bond[2])
        errors
      end

      # La somme des ordres des liaisons d'un atome ne dépasse pas sa valence (Fe et Na ne sont pas contrôlés).
      def self.valence_errors(atoms, bonds)
        used = Hash.new(0)
        bonds.each do |a, b, order|
          used[a] += order
          used[b] += order
        end
        atoms.each_with_index.filter_map do |atom, index|
          max = FigureKinds::MOLECULE_VALENCE[atom["element"]]
          violation("params.atoms[#{index}]", "atoms[#{index}]") if max && used[atom["id"]] > max
        end
      end

      def self.list_of(params, name) = params[name].is_a?(Array) ? params[name] : []
      def self.text?(value) = value.is_a?(String) && !value.strip.empty?
      def self.within?(value, span) = number?(value) && span.cover?(value)
      def self.category?(value, legend) = value.is_a?(Integer) && (1..legend).cover?(value)

      def self.both_numbers?(params, low, high) = number?(params[low]) && number?(params[high])

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
        range = adjusted_range(raw, control["param"])
        errors << violation("#{path}.min", "#{path}.min") unless number?(min) && whole?(control, min) && bound.cover?(min) && (range.nil? || range.cover?(min))
        errors << violation("#{path}.max", "#{path}.max") unless number?(max) && whole?(control, max) && bound.cover?(max) && (!number?(min) || max > min) && (range.nil? || range.cover?(max))
        errors << violation("#{path}.step", "#{path}.step") unless number?(step) && whole?(control, step) && step.positive? && (!number?(min) || !number?(max) || max <= min || step <= max - min)
        label = control["label"]
        errors << violation("#{path}.label", "#{path}.label") unless label.is_a?(String) && (1..FigureKinds::LABEL_MAX).cover?(label.length)
        errors.concat(timeline_control_errors(control, path, raw)) if errors.empty?
        errors
      end

      # Le curseur du nombre de carbones n'a que des valeurs entières (molecule.js refuse un nombre à virgule).
      def self.whole?(control, value) = control["param"] != "carbons" || value.is_a?(Integer)

      # Frise : aux extrêmes du curseur, end reste après start et les graduations restent au plus MAX_TICKS.
      def self.timeline_control_errors(control, path, raw)
        params = raw["params"]
        return [] unless raw["kind"] == "timeline" && params.is_a?(Hash) && both_numbers?(params, "start", "end")

        step = params["step"]
        if control["param"] == "start"
          return [ violation("#{path}.max", "#{path}.max") ] unless control["max"] < params["end"]

          too_many_ticks?(control["min"], params["end"], step) ? [ violation("#{path}.min", "#{path}.min") ] : []
        else
          return [ violation("#{path}.min", "#{path}.min") ] unless control["min"] > params["start"]

          too_many_ticks?(params["start"], control["max"], step) ? [ violation("#{path}.max", "#{path}.max") ] : []
        end
      end

      # La clé est déclarée réglable par la sorte et présente dans `params` avec une valeur numérique.
      def self.adjustable?(raw, name)
        return true unless FigureKinds.known?(raw["kind"]) && raw["params"].is_a?(Hash)

        FigureKinds.fetch(raw["kind"]).adjustable.include?(name) && number?(raw["params"][name])
      end

      # Le `range` du paramètre réglé : un curseur ne peut pas sortir de ce que la sorte accepte pour lui.
      def self.adjusted_range(raw, name)
        return unless FigureKinds.known?(raw["kind"]) && name.is_a?(String)

        spec = FigureKinds.fetch(raw["kind"]).params[name]
        spec&.range
      end

      def self.number?(value) = value.is_a?(Numeric)
    end
  end
end

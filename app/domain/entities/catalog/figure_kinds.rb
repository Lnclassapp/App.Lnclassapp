# 🧠 DOMAINE · Entities::Catalog::FigureKinds
# Rôle : liste fermée des onze sortes de figures d'une leçon et bornes de leurs paramètres (une sorte nouvelle = un amendement de l'ADR)
# ADR  : 0116-fiche-de-revision-par-notion-et-figures-parametrees (§4.2), XXXX-figures-des-matieres-de-3eme (§4.2) · UDR : 0141-fiche-de-revision-en-quatre-blocs
defined?(Entities::Catalog::FigureCatalogs) || require_relative("figure_catalogs")

module Entities
  module Catalog
    module FigureKinds
      # type : :list (éléments : objet de valeurs simples, tableau de valeurs simples, nombre ou texte), :number ou :enum.
      # max : longueur d'une liste ; range : bornes d'un nombre ; values : choix d'une énumération.
      Param = Data.define(:type, :max, :range, :values) do
        def initialize(max: nil, range: nil, values: nil, **) = super
      end
      # item_range : bornes de tout nombre porté par un élément de liste (coordonnées, rayons, valeurs).
      # adjustable : clés numériques de premier niveau de `params` qu'un curseur (`controls[].param`) peut régler.
      # required : lambda (params) → noms des paramètres que le navigateur exige pour dessiner (lib/figures/<sorte>.js, `read`).
      Kind = Data.define(:name, :params, :item_range, :adjustable, :required)

      TEXT_MAX = 60
      ITEM_ARRAY_MAX = 4
      CONTROLS_MAX = 4
      LABEL_MAX = 40
      CONTROL_BOUND = 3_000 # bornes d'un curseur : couvre les années d'une frise (−3000..2100)
      KEY_PATTERN = /\A[a-z0-9][a-z0-9-]{0,39}\z/
      PARAM_PATTERN = /\A[a-z][a-z0-9_]{0,29}\z/
      DESCRIPTION_LENGTH = (150..600)
      MAX_PER_LESSON = 12
      MAX_TICKS = 200 # number_line.js : (max - min) / step au plus

      def self.list(max) = Param.new(type: :list, max:)
      def self.number(range) = Param.new(type: :number, range:)
      def self.enum(*values) = Param.new(type: :enum, values:)

      # solid.js : un cône veut radius et height ; une pyramide veut sa base, puis width + depth + height (rectangulaire) ou side + height.
      SOLID_REQUIRED = lambda do |params|
        case params["shape"]
        when "cone" then %w[radius height]
        when "pyramid"
          case params["base"]
          when "rectangular" then %w[base width depth height]
          when "square", "triangular" then %w[base side height]
          else %w[base]
          end
        else %w[shape]
        end
      end

      # optics.js : la lentille veut sa nature, sa focale, la distance et la hauteur de l'objet ; l'œil veut son défaut.
      OPTICS_REQUIRED = lambda do |params|
        case params["mode"]
        when "lens" then %w[lens focal object_distance object_height]
        when "eye" then %w[defect]
        else %w[mode]
        end
      end

      # molecule.js : un alcane veut son nombre de carbones et son affichage ; un dessin libre veut ses atomes et ses liaisons.
      MOLECULE_REQUIRED = lambda do |params|
        case params["mode"]
        when "alkane" then %w[carbons display]
        when "custom" then %w[atoms bonds]
        else %w[mode]
        end
      end
      MOLECULE_ELEMENTS = %w[C H O N Cl Fe Na].freeze
      MOLECULE_VALENCE = { "C" => 4, "H" => 1, "O" => 2, "N" => 3, "Cl" => 1 }.freeze # Fe et Na : non contrôlés
      MOLECULE_GRID = (0..12)
      BOND_ORDERS = (1..3)

      ALL = {
        "geometry" => Kind.new(name: "geometry", item_range: (-20..20), adjustable: [].freeze, required: ->(_) { %w[points] },
                               params: { "points" => list(12), "segments" => list(30), "lines" => list(12), "circles" => list(6),
                                         "angles" => list(12), "labels" => list(20), "constraints" => list(12) }),
        "coordinate_plane" => Kind.new(name: "coordinate_plane", item_range: (-50..50), adjustable: %w[xmin xmax ymin ymax].freeze,
                                       required: ->(_) { %w[xmin xmax ymin ymax] },
                                       params: { "xmin" => number(-50..50), "xmax" => number(-50..50), "ymin" => number(-50..50),
                                                 "ymax" => number(-50..50), "points" => list(12), "vectors" => list(8),
                                                 "lines" => list(6), "segments" => list(12) }),
        "number_line" => Kind.new(name: "number_line", item_range: (-100..100), adjustable: %w[min max step].freeze,
                                  required: ->(_) { %w[min max step] },
                                  params: { "min" => number(-100..100), "max" => number(-100..100), "step" => number(0.01..50),
                                            "points" => list(12), "intervals" => list(6) }),
        "stat_chart" => Kind.new(name: "stat_chart", item_range: (-1_000_000..1_000_000), adjustable: [].freeze, required: ->(_) { %w[chart series] },
                                 params: { "chart" => enum("bars", "histogram", "pie", "line"), "series" => list(20), "labels" => list(20) }),
        "solid" => Kind.new(name: "solid", item_range: (0.5..50), adjustable: %w[height side width depth radius].freeze, required: SOLID_REQUIRED,
                            params: { "shape" => enum("pyramid", "cone"), "base" => enum("square", "rectangular", "triangular"),
                                      "height" => number(0.5..50), "side" => number(0.5..50), "width" => number(0.5..50),
                                      "depth" => number(0.5..50), "radius" => number(0.5..50) }),
        "timeline" => Kind.new(name: "timeline", item_range: (-3000..2100), adjustable: %w[start end].freeze, required: ->(_) { %w[start end step] },
                               params: { "start" => number(-3000..2100), "end" => number(-3000..2100), "step" => number(1..500),
                                         "unit" => enum("year", "month", "day"), "periods" => list(8), "events" => list(16) }),
        "map" => Kind.new(name: "map", item_range: (1..6), adjustable: [].freeze, required: ->(_) { %w[base] },
                          params: { "base" => enum("cote_d_ivoire", "africa", "world"), "areas" => list(40), "places" => list(20),
                                    "routes" => list(10), "legend" => list(6) }),
        "diagram" => Kind.new(name: "diagram", item_range: (1..4), adjustable: [].freeze, required: ->(_) { %w[layout nodes] },
                              params: { "layout" => enum("flow", "tree", "cycle"), "direction" => enum("down", "right"),
                                        "nodes" => list(12), "edges" => list(16), "legend" => list(4) }),
        "plate" => Kind.new(name: "plate", item_range: (0..1), adjustable: [].freeze, required: ->(_) { %w[plate labels numbering] },
                            params: { "plate" => enum(*FigureCatalogs::PLATES.keys), "labels" => list(12), "highlight" => list(4),
                                      "numbering" => enum("names", "numbers") }),
        "optics" => Kind.new(name: "optics", item_range: (0.5..60), adjustable: %w[focal object_distance object_height].freeze, required: OPTICS_REQUIRED,
                             params: { "mode" => enum("lens", "eye"), "lens" => enum("convergent", "divergent"), "focal" => number(0.5..20),
                                       "object_distance" => number(0.5..60), "object_height" => number(0.5..10),
                                       "defect" => enum("none", "myopia", "hyperopia"), "correction" => enum("none", "convergent", "divergent") }),
        "molecule" => Kind.new(name: "molecule", item_range: MOLECULE_GRID, adjustable: %w[carbons].freeze, required: MOLECULE_REQUIRED,
                               params: { "mode" => enum("alkane", "custom"), "carbons" => number(1..10),
                                         "display" => enum("developed", "semi_developed", "raw"), "atoms" => list(20), "bonds" => list(24) })
      }.freeze
      NAMES = ALL.keys.freeze

      def self.known?(kind) = ALL.key?(kind)
      def self.fetch(kind) = ALL.fetch(kind)
    end
  end
end

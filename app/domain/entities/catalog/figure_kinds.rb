# 🧠 DOMAINE · Entities::Catalog::FigureKinds
# Rôle : liste fermée des cinq sortes de figures d'une leçon et bornes de leurs paramètres (une sorte nouvelle = un amendement de l'ADR)
# ADR  : 0116-fiche-de-revision-par-notion-et-figures-parametrees (§4.2) · UDR : 0141-fiche-de-revision-en-quatre-blocs
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
      CONTROL_BOUND = 1_000
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
                                 params: { "chart" => enum("bars", "histogram", "pie"), "series" => list(20), "labels" => list(20) }),
        "solid" => Kind.new(name: "solid", item_range: (0.5..50), adjustable: %w[height side width depth radius].freeze, required: SOLID_REQUIRED,
                            params: { "shape" => enum("pyramid", "cone"), "base" => enum("square", "rectangular", "triangular"),
                                      "height" => number(0.5..50), "side" => number(0.5..50), "width" => number(0.5..50),
                                      "depth" => number(0.5..50), "radius" => number(0.5..50) })
      }.freeze
      NAMES = ALL.keys.freeze

      def self.known?(kind) = ALL.key?(kind)
      def self.fetch(kind) = ALL.fetch(kind)
    end
  end
end

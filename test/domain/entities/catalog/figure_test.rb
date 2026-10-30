require "test_helper"

# ADR-0116 §4.2 : sortes fermées, paramètres bornés, contrôles de 0 à 4.
module Entities
  module Catalog
    class FigureTest < ActiveSupport::TestCase
      def raw(**changes) = revision_figure.merge(changes.stringify_keys)
      def solid(**changes) = raw(kind: "solid", params: { "shape" => "cone", "height" => 4, "radius" => 3 }, **changes)
      def reasons(figure) = Figure.errors_for(figure).map { it.first(2) }

      test "la figure de la fabrique est valide" do
        assert_empty Figure.errors_for(raw)
      end

      test "la liste des sortes est fermée : huit sortes" do
        assert_equal %w[coordinate_plane diagram geometry map number_line solid stat_chart timeline], FigureKinds::ALL.keys.sort
        assert_equal [ "kind", "figure_invalid", { param: "kind" } ], Figure.errors_for(raw(kind: "hologram")).first
      end

      test "description obligatoire de 150 à 600 caractères" do
        assert_equal [ [ "description", "figure_invalid" ] ], reasons(raw(description: "a" * 149))
        assert_equal [ [ "description", "figure_invalid" ] ], reasons(raw(description: "a" * 601))
        assert_empty Figure.errors_for(raw(description: "a" * 150))
        assert_empty Figure.errors_for(raw(description: "a" * 600))
      end

      test "la clé est obligatoire et de forme restreinte" do
        assert_equal [ [ "key", "figure_invalid" ] ], reasons(raw(key: "Clé avec espaces"))
        assert_equal [ [ "key", "figure_invalid" ] ], reasons(raw(key: nil))
      end

      test "un paramètre inconnu est refusé et nommé" do
        errors = Figure.errors_for(raw(params: { "script" => "x", "points" => [ { "id" => "A", "x" => 0, "y" => 0 } ] }))

        assert_equal [ [ "params.script", "figure_invalid", { param: "script" } ] ], errors
      end

      test "geometry : au plus 12 points, coordonnées de -20 à 20" do
        points = Array.new(13) { { "id" => "P#{it}", "x" => 0, "y" => 0 } }
        assert_equal [ [ "params.points", "figure_invalid" ] ], reasons(raw(params: { "points" => points }))
        far = [ { "id" => "A", "x" => 21, "y" => 0 } ]
        assert_equal [ [ "params.points[0].x", "figure_invalid" ] ], reasons(raw(params: { "points" => far }))
      end

      test "chaque sorte accepte ses paramètres bornés" do
        valid = { "coordinate_plane" => { "xmin" => -5, "xmax" => 5, "ymin" => -5, "ymax" => 5, "lines" => [ { "a" => 2, "b" => 1 } ] },
                  "number_line" => { "min" => -3, "max" => 8, "step" => 1, "intervals" => [ { "from" => 1, "to" => 4, "closed_from" => true, "closed_to" => false } ] },
                  "stat_chart" => { "chart" => "bars", "series" => [ 3, 5, 8 ], "labels" => %w[a b c] },
                  "solid" => { "shape" => "pyramid", "base" => "square", "height" => 6, "side" => 4 } }
        valid.each { |kind, params| assert_empty Figure.errors_for(raw(kind:, params:)), kind }
      end

      test "stat_chart : graphique hors liste et plus de 20 valeurs refusés ; solid : forme hors liste refusée" do
        assert_equal [ [ "params.chart", "figure_invalid" ] ], reasons(raw(kind: "stat_chart", params: { "chart" => "radar", "series" => [ 1 ] }))
        assert_equal [ [ "params.series", "figure_invalid" ] ], reasons(raw(kind: "stat_chart", params: { "chart" => "bars", "series" => Array.new(21, 1) }))
        assert_equal [ [ "params.shape", "figure_invalid" ] ], reasons(raw(kind: "solid", params: { "shape" => "cube" }))
      end

      test "un curseur vise une clé numérique de premier niveau que la sorte déclare réglable et que params contient" do
        control = { "param" => "height", "min" => 1, "max" => 9, "step" => 0.5, "label" => "hauteur" }
        cone = solid(controls: [ control ])
        assert_empty Figure.errors_for(cone)
        assert_equal [ [ "params.height", "figure_invalid" ], [ "controls[0].param", "figure_invalid" ] ], reasons(cone.merge("params" => { "shape" => "cone", "radius" => 3 }))
        assert_equal [ [ "controls[0].param", "figure_invalid" ] ], reasons(cone.merge("controls" => [ control.merge("param" => "shape") ]))
        assert_equal [ [ "controls[0].param", "figure_invalid" ] ], reasons(raw(controls: [ control.merge("param" => "points") ]))
        assert_equal [ [ "controls[0].param", "figure_invalid" ] ], reasons(raw(controls: [ control.merge("param" => "inconnu") ]))
        assert_equal [ "controls[0].param", "figure_invalid", { param: "controls[0].param" } ], Figure.errors_for(raw(controls: [ control ])).first
        assert_empty FigureKinds.fetch("geometry").adjustable
      end

      test "controls : 0 à 4, bornes cohérentes, libellé court" do
        control = { "param" => "height", "min" => 1, "max" => 9, "step" => 1, "label" => "hauteur" }
        assert_empty Figure.errors_for(solid(controls: []))
        assert_equal [ [ "controls", "figure_invalid" ] ], reasons(solid(controls: Array.new(5) { control }))
        assert_equal [ [ "controls[0].max", "figure_invalid" ] ], reasons(solid(controls: [ control.merge("max" => 0) ]))
        assert_equal [ [ "controls[0].step", "figure_invalid" ] ], reasons(solid(controls: [ control.merge("step" => 0) ]))
        assert_equal [ [ "controls[0].label", "figure_invalid" ] ], reasons(solid(controls: [ control.merge("label" => "") ]))
      end

      test "un curseur dont les bornes sortent du range du paramètre réglé est refusé" do
        control = { "param" => "height", "min" => 1, "max" => 9, "step" => 1, "label" => "hauteur" }

        assert_equal [ [ "controls[0].min", "figure_invalid" ] ], reasons(solid(controls: [ control.merge("min" => 0) ]))
        assert_equal [ [ "controls[0].max", "figure_invalid" ] ], reasons(solid(controls: [ control.merge("max" => 51) ]))
      end

      test "les paramètres que le navigateur exige sont obligatoires, par sorte" do
        assert_equal %w[params.xmin params.xmax params.ymin params.ymax], reasons(raw(kind: "coordinate_plane", params: { "points" => [] })).map(&:first)
        assert_equal %w[params.min params.max params.step], reasons(raw(kind: "number_line", params: {})).map(&:first)
        assert_equal %w[params.chart params.series], reasons(raw(kind: "stat_chart", params: {})).map(&:first)
        assert_equal %w[params.shape], reasons(raw(kind: "solid", params: {})).map(&:first)
        assert_equal %w[params.points], reasons(raw(params: {})).map(&:first)
        assert_equal %w[params.points], reasons(raw(params: { "points" => [] })).map(&:first)
        assert_equal %w[params.radius], reasons(solid(params: { "shape" => "cone", "height" => 4 })).map(&:first)
        assert_equal %w[params.base], reasons(raw(kind: "solid", params: { "shape" => "pyramid", "height" => 4 })).map(&:first)
        assert_equal %w[params.width params.depth], reasons(raw(kind: "solid", params: { "shape" => "pyramid", "base" => "rectangular", "height" => 4 })).map(&:first)
        assert_equal %w[params.side], reasons(raw(kind: "solid", params: { "shape" => "pyramid", "base" => "square", "height" => 4 })).map(&:first)
        assert_equal [ "params.min", "figure_invalid", { param: "min" } ], Figure.errors_for(raw(kind: "number_line", params: {})).first
      end

      test "les bornes doivent être ordonnées et la figure dessinable" do
        plane = ->(**p) { raw(kind: "coordinate_plane", params: { "xmin" => -5, "xmax" => 5, "ymin" => -5, "ymax" => 5 }.merge(p.stringify_keys)) }
        line = ->(**p) { raw(kind: "number_line", params: { "min" => 0, "max" => 10, "step" => 1 }.merge(p.stringify_keys)) }

        assert_equal %w[params.xmax], reasons(plane.(xmax: -5)).map(&:first)
        assert_equal %w[params.ymax], reasons(plane.(ymax: -9)).map(&:first)
        assert_equal %w[params.max], reasons(line.(max: 0)).map(&:first)
        assert_equal %w[params.step], reasons(line.(max: 50, step: 0.1)).map(&:first)
        pie = ->(series) { raw(kind: "stat_chart", params: { "chart" => "pie", "series" => series }) }
        assert_equal %w[params.series[1]], reasons(pie.([ 1, -2 ])).map(&:first)
        assert_equal %w[params.series], reasons(pie.([ 0, 0 ])).map(&:first)
        dup = [ { "id" => "A", "x" => 0, "y" => 0 }, { "id" => "A", "x" => 1, "y" => 1 } ]
        assert_equal %w[params.points[1].id], reasons(raw(params: { "points" => dup })).map(&:first)
        assert_equal %w[params.points[0].y], reasons(raw(params: { "points" => [ { "id" => "A", "x" => 0 } ] })).map(&:first)
      end

      test "une figure qui n'est pas un objet est refusée à la racine, sans lever" do
        [ nil, "figure", 3, [] ].each do |value|
          assert_equal [ [ "$", "figure_invalid", { param: "$" } ] ], Figure.errors_for(value), value.inspect
        end
      end

      test "params qui n'est pas un objet est refusé une seule fois" do
        assert_equal [ [ "params", "figure_invalid" ] ], reasons(raw(params: "x"))
        assert_equal [ [ "params", "figure_invalid" ] ], reasons(raw(params: [ 1 ]))
      end

      test "geometry : points qui n'est pas une liste ou dont un point n'est pas un objet est refusé" do
        assert_equal [ [ "params.points", "figure_invalid" ] ], reasons(raw(params: { "points" => "A" }))
        assert_includes reasons(raw(params: { "points" => [ "A" ] })), [ "params.points[0]", "figure_invalid" ]
        assert_includes reasons(raw(params: { "points" => [ true ] })), [ "params.points[0]", "figure_invalid" ]
        assert_includes reasons(raw(params: { "points" => [ nil ] })), [ "params.points[0]", "figure_invalid" ]
      end

      test "un nombre de paramètre hors bornes est refusé et nommé" do
        errors = Figure.errors_for(raw(kind: "number_line", params: { "min" => 500, "max" => 600, "step" => 1 }))

        assert_includes errors, [ "params.min", "figure_invalid", { param: "min" } ]
        assert_includes errors, [ "params.max", "figure_invalid", { param: "max" } ]
        assert_equal [ [ "params.step", "figure_invalid" ] ], reasons(raw(kind: "number_line", params: { "min" => 0, "max" => 10, "step" => 100 }))
        assert_equal [ [ "params.min", "figure_invalid" ] ], reasons(raw(kind: "number_line", params: { "min" => "a", "max" => 10, "step" => 1 }))
      end

      test "stat_chart : une série qui n'est pas une liste est refusée une seule fois" do
        assert_equal [ [ "params.series", "figure_invalid" ] ], reasons(raw(kind: "stat_chart", params: { "chart" => "bars", "series" => 5 }))
      end

      test "un élément de liste hors bornes, trop long ou de mauvaise forme est refusé" do
        points = ->(item) { raw(params: { "points" => [ { "id" => "A", "x" => 0, "y" => 0 } ], "labels" => [ item ] }) }

        assert_empty Figure.errors_for(points.(5))
        assert_equal [ [ "params.labels[0]", "figure_invalid" ] ], reasons(points.(21))
        assert_equal [ [ "params.labels[0]", "figure_invalid" ] ], reasons(points.("a" * 61))
        assert_equal [ [ "params.labels[0]", "figure_invalid" ] ], reasons(points.([ 1, 2, 3, 4, 5 ]))
        assert_equal [ [ "params.labels[0]", "figure_invalid" ] ], reasons(points.(true))
        assert_equal [ [ "params.labels[0]", "figure_invalid" ] ], reasons(points.(nil))
      end

      test "les valeurs imbriquées d'un élément sont bornées et d'un type simple" do
        nested = ->(item) { raw(params: { "points" => [ { "id" => "A", "x" => 0, "y" => 0 } ], "labels" => [ item ] }) }

        assert_empty Figure.errors_for(nested.([ 1, "a", true, false ]))
        assert_empty Figure.errors_for(nested.({ "k" => 1, "t" => "a", "flag" => true }))
        assert_equal [ [ "params.labels[0][1]", "figure_invalid" ] ], reasons(nested.([ 1, 99 ]))
        assert_equal [ [ "params.labels[0].t", "figure_invalid" ] ], reasons(nested.({ "t" => "a" * 61 }))
        assert_equal [ [ "params.labels[0][0]", "figure_invalid" ] ], reasons(nested.([ nil ]))
        assert_equal [ [ "params.labels[0].k", "figure_invalid" ] ], reasons(nested.({ "k" => [ 1 ] }))
      end

      test "controls absent est valide ; un curseur qui n'est pas un objet est refusé" do
        assert_empty Figure.errors_for(raw.except("controls"))
        assert_equal [ [ "controls[0]", "figure_invalid", { param: "controls[0]" } ] ], Figure.errors_for(solid(controls: [ "height" ]))
        assert_equal [ [ "controls", "figure_invalid", { param: "controls" } ] ], Figure.errors_for(solid(controls: "height"))
      end

      test "un curseur d'une figure de sorte inconnue ou à clé qui n'est pas un texte ne lève pas" do
        control = { "param" => "height", "min" => 1, "max" => 9, "step" => 1, "label" => "hauteur" }

        assert_equal [ [ "kind", "figure_invalid" ] ], reasons(raw(kind: "hologram", controls: [ control ]))
        assert_equal [ [ "controls[0].param", "figure_invalid" ] ], reasons(solid(controls: [ control.merge("param" => 5) ]))
        assert_equal [ [ "controls[0].param", "figure_invalid" ] ], reasons(solid(controls: [ control.merge("param" => nil) ]))
      end

      def timeline(**params) = raw(kind: "timeline", params: TIMELINE.merge(params.transform_keys(&:to_s)))
      def map(**params) = raw(kind: "map", params: MAP.merge(params.transform_keys(&:to_s)))
      def diagram(**params) = raw(kind: "diagram", params: FLOW.merge(params.transform_keys(&:to_s)))
      def paths(figure) = reasons(figure).map(&:first).uniq

      TIMELINE = { "start" => 1880, "end" => 1960, "step" => 10, "unit" => "year",
                   "periods" => [ { "from" => 1884, "to" => 1914, "label" => "Conquête" } ],
                   "events" => [ { "at" => 1893, "label" => "Colonie" }, { "at" => 1960, "label" => "Indépendance" } ] }.freeze
      MAP = { "base" => "cote_d_ivoire", "legend" => %w[Forêt Savane],
              "areas" => [ { "id" => "dense_forest", "category" => 1 }, { "id" => "savanna", "category" => 2 } ],
              "places" => [ { "id" => "abidjan", "label" => "Capitale" }, { "id" => "korhogo" } ],
              "routes" => [ { "from" => "abidjan", "to" => "korhogo", "label" => "Route" }, { "from" => "abidjan", "to" => "man" } ] }.freeze
      FLOW = { "layout" => "flow", "direction" => "right", "legend" => %w[Étape],
               "nodes" => [ { "id" => "a", "label" => "Début", "category" => 1 }, { "id" => "b", "label" => "Fin" } ],
               "edges" => [ { "from" => "a", "to" => "b", "label" => "puis" }, { "from" => "b", "to" => "a" } ] }.freeze
      TREE_NODES = %w[r a b c].map { { "id" => it, "label" => it.upcase } }.freeze

      test "une figure bien formée de chaque sorte nouvelle, de chaque fond et de chaque schéma est valide" do
        assert_empty Figure.errors_for(timeline)
        assert_empty Figure.errors_for(timeline(unit: "month", periods: [], events: []))
        assert_empty Figure.errors_for(raw(kind: "timeline", params: { "start" => 0, "end" => 10, "step" => 1 }))
        assert_empty Figure.errors_for(map)
        assert_empty Figure.errors_for(map(base: "africa", areas: [ { "id" => "civ", "category" => 1 } ], places: [ { "id" => "abidjan" } ], routes: [ { "from" => "dakar", "to" => "lagos" } ]))
        assert_empty Figure.errors_for(map(base: "world", areas: [ { "id" => "africa", "category" => 2 } ], places: [ { "id" => "yalta" } ], routes: []))
        assert_empty Figure.errors_for(raw(kind: "map", params: { "base" => "world" }))
        assert_empty Figure.errors_for(diagram)
        assert_empty Figure.errors_for(raw(kind: "diagram", params: { "layout" => "flow", "nodes" => [ { "id" => "a", "label" => "A" } ] }))
        edges = [ { "from" => "r", "to" => "a" }, { "from" => "r", "to" => "b" }, { "from" => "a", "to" => "c" } ]
        assert_empty Figure.errors_for(diagram(layout: "tree", direction: "down", nodes: TREE_NODES, edges:))
        ring = %w[a b c].map { { "id" => it, "label" => it } }
        assert_empty Figure.errors_for(diagram(layout: "cycle", nodes: ring, edges: [ { "from" => "a", "to" => "b" }, { "from" => "b", "to" => "c" }, { "from" => "c", "to" => "a" } ]))
        assert_empty Figure.errors_for(raw(kind: "stat_chart", params: { "chart" => "line", "series" => [ 1, 3, 2 ], "labels" => %w[a b c] }))
      end

      test "timeline : curseurs sur start et end seulement" do
        control = { "param" => "start", "min" => 1850, "max" => 1900, "step" => 5, "label" => "début" }

        assert_empty Figure.errors_for(timeline.merge("controls" => [ control ]))
        assert_empty Figure.errors_for(timeline.merge("controls" => [ control.merge("param" => "end") ]))
        assert_includes reasons(timeline.merge("controls" => [ control.merge("param" => "step") ])), [ "controls[0].param", "figure_invalid" ]
        assert_equal [ [ "controls[0].max", "figure_invalid" ] ], reasons(timeline.merge("controls" => [ control.merge("max" => 2101) ]))
      end

      test "map et diagram n'ont aucun curseur" do
        assert_empty FigureKinds.fetch("map").adjustable
        assert_empty FigureKinds.fetch("diagram").adjustable
        assert_equal %w[start end], FigureKinds.fetch("timeline").adjustable
      end

      test "les paramètres exigés par les sortes nouvelles" do
        assert_equal %w[params.start params.end params.step], paths(raw(kind: "timeline", params: {}))
        assert_equal %w[params.base], paths(raw(kind: "map", params: {}))
        assert_equal %w[params.layout params.nodes], paths(raw(kind: "diagram", params: {}))
      end

      test "les bornes génériques des sortes nouvelles" do
        assert_includes paths(timeline(start: -3001)), "params.start"
        assert_equal %w[params.step], paths(timeline(step: 0))
        assert_equal %w[params.unit], paths(timeline(unit: "hour"))
        assert_equal %w[params.periods], paths(timeline(periods: Array.new(9) { { "from" => 1900, "to" => 1901, "label" => "p" } }))
        assert_equal %w[params.base], paths(map(base: "moon", areas: [], places: [], routes: []))
        assert_equal %w[params.legend], paths(map(legend: Array.new(7, "a")))
        assert_equal %w[params.layout], paths(diagram(layout: "spiral"))
        assert_equal %w[params.nodes], paths(diagram(nodes: Array.new(13) { { "id" => "n#{it}", "label" => "n" } }, edges: []))
      end

      test "timeline : end après start, au plus 200 graduations" do
        assert_equal [ [ "params.end", "figure_invalid", { param: "end" } ] ], Figure.errors_for(timeline(end: 1880, events: [], periods: []))
        assert_equal %w[params.end], paths(timeline(end: 1800, events: [], periods: []))
        assert_empty Figure.errors_for(timeline(start: 0, end: 200, step: 1, events: [], periods: []))
        assert_equal [ [ "params.step", "figure_invalid", { param: "step" } ] ], Figure.errors_for(timeline(start: 0, end: 201, step: 1, events: [], periods: []))
        assert_equal %w[params.end], paths(timeline(end: "x"))
      end

      test "timeline : événements dans la plage, avec un libellé" do
        assert_equal %w[params.events[0].at], paths(timeline(events: [ { "at" => 1879, "label" => "x" } ]))
        assert_equal %w[params.events[0].at], paths(timeline(events: [ { "at" => 1961, "label" => "x" } ]))
        assert_equal %w[params.events[0].at], paths(timeline(events: [ { "label" => "x" } ]))
        assert_equal %w[params.events[0].at], paths(timeline(events: [ { "at" => "1900", "label" => "x" } ]))
        assert_equal %w[params.events[0].label], paths(timeline(events: [ { "at" => 1900, "label" => " " } ]))
        assert_equal %w[params.events[0].label], paths(timeline(events: [ { "at" => 1900 } ]))
        assert_equal %w[params.events[1]], paths(timeline(events: [ { "at" => 1900, "label" => "x" }, "x" ]))
        assert_equal [ [ "params.events[0]", "figure_invalid", { param: "events[0]" } ] ], Figure.errors_for(timeline(events: [ 1900 ]))
      end

      test "timeline : périodes dans la plage, ordonnées, avec un libellé" do
        period = ->(**p) { timeline(periods: [ { "from" => 1900, "to" => 1910, "label" => "x" }.merge(p.transform_keys(&:to_s)) ]) }

        assert_empty Figure.errors_for(period.())
        assert_equal %w[params.periods[0].from], paths(period.(from: 1800))
        assert_equal %w[params.periods[0].to], paths(period.(to: 2000))
        assert_equal %w[params.periods[0].to], paths(period.(to: 1900))
        assert_equal %w[params.periods[0].to], paths(period.(to: 1890))
        assert_equal %w[params.periods[0].from], paths(period.(from: "x"))
        assert_equal %w[params.periods[0].to], paths(period.(to: nil))
        assert_equal %w[params.periods[0].label], paths(period.(label: ""))
        assert_equal %w[params.periods[0]], paths(timeline(periods: [ 5 ]))
      end

      test "timeline : des listes qui ne sont pas des tableaux ne lèvent pas" do
        assert_equal %w[params.periods params.events], paths(timeline(events: "x", periods: {}))
      end

      test "map : une aire connue du fond, une seule fois, d'une catégorie de la légende" do
        area = ->(*areas) { map(areas:) }

        assert_equal %w[params.areas[0].id], paths(area.({ "id" => "abidjan_nord", "category" => 1 }))
        assert_equal %w[params.areas[0].id], paths(area.({ "id" => "civ", "category" => 1 }))
        assert_equal %w[params.areas[1].id], paths(area.({ "id" => "savanna", "category" => 1 }, { "id" => "savanna", "category" => 2 }))
        assert_equal %w[params.areas[0].category], paths(area.({ "id" => "savanna", "category" => 3 }))
        assert_equal %w[params.areas[0].category], paths(area.({ "id" => "savanna", "category" => 0 }))
        assert_equal %w[params.areas[0].category], paths(area.({ "id" => "savanna", "category" => 1.5 }))
        assert_equal %w[params.areas[0].category], paths(area.({ "id" => "savanna" }))
        assert_equal %w[params.areas[0].id], paths(area.({ "id" => 5, "category" => 1 }))
        assert_equal %w[params.areas[0]], paths(area.("savanna"))
        assert_equal [ [ "params.areas[0].id", "figure_invalid", { param: "areas[0].id" } ] ], Figure.errors_for(area.({ "id" => "x", "category" => 1 }))
      end

      test "map : une aire sans légende est refusée sur la légende" do
        areas = [ { "id" => "savanna", "category" => 1 } ]

        assert_equal %w[params.legend], paths(map(areas:, legend: []))
        assert_equal %w[params.legend], paths(map(areas:).tap { it["params"].delete("legend") })
        assert_empty Figure.errors_for(map(areas: [], legend: []))
      end

      test "map : les lieux et les routes appartiennent au fond" do
        assert_equal %w[params.places[0].id], paths(map(places: [ { "id" => "paris" } ]))
        assert_equal %w[params.places[1].id], paths(map(places: [ { "id" => "abidjan" }, { "id" => 3 } ]))
        assert_equal %w[params.places[0].label], paths(map(places: [ { "id" => "abidjan", "label" => 4 } ]))
        assert_equal %w[params.places[0]], paths(map(places: [ "abidjan" ]))
        assert_equal %w[params.routes[0].from], paths(map(routes: [ { "from" => "paris", "to" => "man" } ]))
        assert_equal %w[params.routes[0].to], paths(map(routes: [ { "from" => "man", "to" => "paris" } ]))
        assert_equal %w[params.routes[0].label], paths(map(routes: [ { "from" => "man", "to" => "korhogo", "label" => 4 } ]))
        assert_equal %w[params.routes[0]], paths(map(routes: [ "man" ]))
        assert_equal [ [ "params.routes[0].to", "figure_invalid", { param: "routes[0].to" } ] ], Figure.errors_for(map(routes: [ { "from" => "man", "to" => "x" } ]))
      end

      test "map : un fond inconnu ne déclenche qu'une erreur de fond, des listes qui ne sont pas des tableaux ne lèvent pas" do
        assert_equal %w[params.base], paths(map(base: "moon"))
        assert_equal %w[params.areas params.places params.routes], paths(map(areas: "x", places: 1, routes: {}))
      end

      test "diagram : nœuds à identifiant unique, libellé et catégorie de la légende" do
        nodes = ->(*items) { diagram(nodes: items, edges: []) }

        assert_equal %w[params.nodes[0].id], paths(nodes.({ "id" => "", "label" => "A" }))
        assert_equal %w[params.nodes[0].id], paths(nodes.({ "label" => "A" }))
        assert_equal %w[params.nodes[1].id], paths(nodes.({ "id" => "a", "label" => "A" }, { "id" => "a", "label" => "B" }))
        assert_equal %w[params.nodes[0].label], paths(nodes.({ "id" => "a", "label" => " " }))
        assert_equal %w[params.nodes[0].label], paths(nodes.({ "id" => "a" }))
        assert_equal %w[params.nodes[0].category], paths(nodes.({ "id" => "a", "label" => "A", "category" => 2 }))
        assert_equal %w[params.nodes[0].category], paths(nodes.({ "id" => "a", "label" => "A", "category" => 0 }))
        assert_equal %w[params.nodes[0].category], paths(nodes.({ "id" => "a", "label" => "A", "category" => "1" }))
        assert_equal %w[params.nodes[0]], paths(nodes.("a"))
        assert_equal %w[params.nodes[0].category], paths(diagram(nodes: [ { "id" => "a", "label" => "A", "category" => 1 } ], edges: [], legend: []))
        assert_equal [ [ "params.nodes[0].id", "figure_invalid", { param: "nodes[0].id" } ] ], Figure.errors_for(nodes.({ "label" => "A" }))
      end

      test "diagram : arêtes entre deux nœuds existants et différents" do
        edges = ->(*items) { diagram(edges: items) }

        assert_empty Figure.errors_for(edges.())
        assert_equal %w[params.edges[0].from], paths(edges.({ "from" => "z", "to" => "b" }))
        assert_equal %w[params.edges[0].to], paths(edges.({ "from" => "a", "to" => "z" }))
        assert_equal %w[params.edges[0].from params.edges[0].to], paths(edges.({ "from" => 1, "to" => 2 }))
        assert_equal %w[params.edges[0].to], paths(edges.({ "from" => "a", "to" => "a" }))
        assert_equal %w[params.edges[0].label], paths(edges.({ "from" => "a", "to" => "b", "label" => 3 }))
        assert_equal %w[params.edges[0]], paths(edges.("a"))
        assert_equal [ [ "params.edges[0].to", "figure_invalid", { param: "edges[0].to" } ] ], Figure.errors_for(edges.({ "from" => "a", "to" => "z" }))
      end

      test "diagram tree : un seul parent, une seule racine, aucun cycle" do
        tree = ->(edges, nodes = TREE_NODES) { diagram(layout: "tree", nodes:, edges:) }
        edge = ->(from, to) { { "from" => from, "to" => to } }

        assert_equal %w[params.edges[2].to], paths(tree.([ edge.("r", "a"), edge.("r", "b"), edge.("a", "b"), edge.("b", "c") ]))
        assert_equal %w[params.edges], paths(tree.([ edge.("r", "a"), edge.("a", "b") ]))
        assert_equal %w[params.edges], paths(tree.([]))
        assert_equal %w[params.edges], paths(tree.([ edge.("r", "a"), edge.("b", "c"), edge.("c", "b") ]))
        assert_equal %w[params.edges], paths(tree.([ edge.("a", "b"), edge.("b", "c"), edge.("c", "a") ]))
        assert_equal %w[params.edges[0].to], paths(tree.([ edge.("r", "r") ]))
        two_roots = [ { "id" => "x", "label" => "X" }, { "id" => "y", "label" => "Y" } ]
        assert_equal %w[params.edges], paths(tree.([], two_roots))
      end

      test "diagram cycle : au moins trois nœuds" do
        two = %w[a b].map { { "id" => it, "label" => it } }

        assert_equal %w[params.nodes], paths(diagram(layout: "cycle", nodes: two))
        assert_empty Figure.errors_for(diagram(layout: "cycle", nodes: two + [ { "id" => "c", "label" => "c" } ], edges: []))
      end

      test "diagram : des listes qui ne sont pas des tableaux ne lèvent pas" do
        assert_equal %w[params.nodes params.edges], paths(diagram(nodes: "x", edges: 2))
        assert_equal %w[params.layout], paths(raw(kind: "diagram", params: { "layout" => "x", "nodes" => [ { "id" => "a", "label" => "A" } ] }))
        assert_equal %w[params.nodes[1]], paths(diagram(layout: "tree", nodes: [ { "id" => "a", "label" => "A" }, "b" ], edges: []))
      end

      test "from_raw construit la figure" do
        figure = Figure.from_raw(raw)

        assert_equal [ "triangle-thales", "geometry", 0 ], [ figure.key, figure.kind, figure.controls.size ]
      end
    end
  end
end

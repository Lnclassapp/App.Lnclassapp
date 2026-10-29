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

      test "la liste des sortes est fermée : cinq sortes" do
        assert_equal %w[coordinate_plane geometry number_line solid stat_chart], FigureKinds::ALL.keys.sort
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

      test "from_raw construit la figure" do
        figure = Figure.from_raw(raw)

        assert_equal [ "triangle-thales", "geometry", 0 ], [ figure.key, figure.kind, figure.controls.size ]
      end
    end
  end
end

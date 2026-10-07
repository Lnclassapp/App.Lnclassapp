require "test_helper"

module Entities
  module Communication
    # ADR-0081 §4.3 et §6 : l'illustration de l'équipe, et la liste blanche qui gèle le format de ses formes. La lecture
    # du SVG (Lot C) produit ce format, le rendu (Communication::IllustrationsHelper) le consomme : les deux le
    # vérifient par Illustration.valid_shape?.
    class IllustrationTest < ActiveSupport::TestCase
      RECT = { "name" => "rect", "attributes" => { "x" => "8", "y" => "8", "width" => "48", "height" => "48", "rx" => "6" },
               "children" => [] }.freeze
      PATH = { "name" => "path", "attributes" => { "d" => "M4 4h56v56H4z", "fill-rule" => "evenodd" }, "children" => [] }.freeze

      def shape(name, children: [], **attributes)
        { "name" => name, "attributes" => attributes.transform_keys { it.to_s.tr("_", "-") }, "children" => children }
      end

      def valid?(candidate, depth: 1) = Illustration.valid_shape?(candidate, depth:)

      # Une forme imbriquée dans `levels` groupes : sa profondeur est levels + 1.
      def nested(levels, leaf = RECT) = levels.times.reduce(leaf) { |child, _| shape("g", children: [ child ]) }

      test "porte chaque champ du contrat gelé ; une illustration à créer n'a ni id, ni public_id, ni retrait" do
        assert_equal %i[id public_id name view_box shapes created_by_id retired_at], Illustration.members

        drawing = Illustration.new(name: "Bus scolaire", view_box: "0 0 64 64", shapes: [ RECT ], created_by_id: 4)

        assert_equal [ nil, nil, nil, "Bus scolaire", [ RECT ], 4 ],
                     [ drawing.id, drawing.public_id, drawing.retired_at, drawing.name, drawing.shapes, drawing.created_by_id ]
      end

      test "AV-10 — retirée exactement quand elle porte sa date de retrait" do
        drawing = Illustration.new(name: "Bus scolaire", view_box: "0 0 64 64", shapes: [ RECT ], created_by_id: 4)

        assert_not drawing.retired?
        assert drawing.with(retired_at: Time.utc(2026, 10, 5)).retired?
      end

      test "les bornes : nom de 30 caractères, fichier de 50 Ko, 500 formes, 8 niveaux" do
        assert_equal [ 30, 51_200, 500, 8 ],
                     [ Illustration::NAME_MAX, Illustration::MAX_BYTES, Illustration::MAX_SHAPES, Illustration::MAX_DEPTH ]
      end

      test "la liste blanche des éléments et de leurs attributs géométriques (ADR-0081 §4.3)" do
        assert_equal %w[g path rect circle ellipse line polyline polygon], Illustration::ELEMENTS
        assert_equal Illustration::ELEMENTS, Illustration::ATTRIBUTES.keys
        assert_equal({ "g" => %w[transform fill-rule], "path" => %w[d transform fill-rule],
                       "rect" => %w[x y width height rx ry transform], "circle" => %w[cx cy r transform],
                       "ellipse" => %w[cx cy rx ry transform], "line" => %w[x1 y1 x2 y2 transform],
                       "polyline" => %w[points transform fill-rule], "polygon" => %w[points transform fill-rule] },
                     Illustration::ATTRIBUTES)
        assert_equal %w[d x y width height rx ry cx cy r x1 y1 x2 y2 points transform fill-rule].sort,
                     Illustration::PATTERNS.keys.sort
        assert_equal Illustration::PATTERNS.keys.sort, Illustration::ATTRIBUTES.values.flatten.uniq.sort
        assert [ Illustration::ELEMENTS, Illustration::ATTRIBUTES, Illustration::PATTERNS, *Illustration::ATTRIBUTES.values ].all?(&:frozen?)
      end

      test "chaque expression est ancrée au début et à la fin de la valeur" do
        [ *Illustration::PATTERNS.values, Illustration::VIEW_BOX ].each do |pattern|
          assert pattern.source.start_with?("\\A"), pattern.source
          assert pattern.source.end_with?("\\z"), pattern.source
        end
      end

      test "une coordonnée est un nombre, signé, décimal ou à exposant, et rien d'autre" do
        coordinate = Illustration::PATTERNS.fetch("x")

        %w[0 12 -3.5 +.5 4. 1e-5 -1.2E+3 0.26458333].each { assert_match coordinate, it }
        [ "", " 1", "1 ", "1px", "50%", "1,2", "--1", "e5", "1e", "0x10", "1\n", "\n1", "1" * 21, "calc(1)" ].each do |value|
          assert_no_match coordinate, value, value.inspect
        end
        assert(%w[y width height rx ry cx cy r x1 y1 x2 y2].all? { Illustration::PATTERNS.fetch(it) == coordinate })
      end

      test "un tracé d n'a que des commandes de chemin, des nombres, des séparateurs et des exposants ; 20 000 caractères au plus" do
        d = Illustration::PATTERNS.fetch("d")

        [ "M4 4h56v56H4z", "m0,0 l1.5e-3-2 C1 2 3 4 5 6 S7 8 9 10 Q1 2 3 4 T5 6 A1 1 0 0 1 9 9 Z", "M1\n2\tL3\r4",
          "M0 0#{' L1 1' * 3999}" ].each { assert_match d, it }
        [ "", "M0 0 \"><script>alert(1)</script>", "M0 0 url(#a)", "M0 0;", "M0 0 X1", "M0 0 <", "M0 0#{' L1 1' * 4000}" ].each do |value|
          assert_no_match d, value, value.first(40)
        end
      end

      test "des points : des nombres et des séparateurs, 20 000 caractères au plus" do
        points = Illustration::PATTERNS.fetch("points")

        [ "0,0 10,0 10,10", "1e2 -3.5\n4 5" ].each { assert_match points, it }
        [ "", "0,0 L10,10", "0,0 \"onload=", "1" * 20_001 ].each { assert_no_match points, it, it.first(40) }
      end

      test "une transformation : matrix, translate, scale, rotate, skewX et skewY, avec leurs nombres" do
        transform = Illustration::PATTERNS.fetch("transform")

        [ "translate(-12.5,3)", "matrix(0.26458333,0,0,0.26458333,-10.5,20)", "rotate(45 32 32)", "scale(-1)",
          "skewX(10) skewY(-5)", " translate(1, 2) , scale(2) ", "rotate( 45 )" ].each { assert_match transform, it }
        [ "", "translate()", "url(#a)", "translate(1,2", "matrix(1,2,3,4,5,6,7)", "perspective(1)", "translate(1px)",
          "scale(1) javascript:alert(1)", "rotate(1)#{' rotate(1)' * 16}", "translate(1,#{' ' * 2_000}2)" ].each do |value|
          assert_no_match transform, value, value.first(40)
        end
      end

      test "une règle de remplissage est nonzero ou evenodd ; une viewBox, quatre nombres" do
        fill_rule = Illustration::PATTERNS.fetch("fill-rule")

        assert(%w[nonzero evenodd].all? { fill_rule.match?(it) })
        [ "", "inherit", "evenodd;", " evenodd" ].each { assert_no_match fill_rule, it }
        [ "0 0 64 64", "0,0,64,64", "-1.5 0 210 297", " 0 0 64 64 " ].each { assert_match Illustration::VIEW_BOX, it }
        [ "", "0 0 64", "0 0 64 64 64", "0 0 64 64\" onload=\"alert(1)", "0 0 64px 64", "0 0 64 64#{' ' * 200}" ].each do |value|
          assert_no_match Illustration::VIEW_BOX, value, value.inspect
        end
      end

      test "AV-09 — une forme de la liste blanche, avec ses seuls attributs permis, est valide ; un groupe porte ses enfants" do
        assert valid?(RECT)
        assert valid?(PATH)
        assert valid?(shape("circle", cx: "32", cy: "32", r: "8", transform: "scale(2)"))
        assert valid?(shape("polygon", points: "0,0 10,0 10,10"))
        assert valid?(shape("g", transform: "translate(1,2)", children: [ RECT, shape("g", children: [ PATH ]) ]))
        assert valid?(shape("g"))
        assert valid?(shape("line", x1: "0", y1: "0", x2: "64", y2: "64"))
      end

      test "AV-09 — un élément hors liste blanche n'est jamais valide, même caché dans un groupe" do
        %w[script foreignObject image use style iframe a svg text title defs].each do |name|
          assert_not valid?(shape(name)), name
          assert_not valid?(shape("g", children: [ shape(name) ])), name
        end
        assert_not valid?(shape("g", children: [ RECT, "<script>alert(1)</script>" ]))
      end

      test "AV-09 — un attribut hors liste, ou permis ailleurs seulement, rend la forme invalide" do
        [ { onload: "alert(1)" }, { href: "https://evil.example" }, { "xlink:href": "#a" }, { style: "fill:red" },
          { fill: "red" }, { class: "x" }, { id: "a" } ].each do |attributes|
          assert_not valid?(RECT.merge("attributes" => RECT["attributes"].merge(attributes.transform_keys(&:to_s)))), attributes.inspect
        end
        assert_not valid?(shape("rect", d: "M0 0"))
        assert_not valid?(shape("circle", points: "0,0"))
        assert_not valid?(shape("g", x: "1"))
      end

      test "AV-09 — une valeur qui sort de son expression rend la forme invalide" do
        assert_not valid?(shape("path", d: "M0 0\"><script>alert(1)</script>"))
        assert_not valid?(shape("rect", x: "1\" onload=\"alert(1)"))
        assert_not valid?(shape("g", transform: "url(#a)"))
        assert_not valid?(shape("path", d: "M0 0", fill_rule: "inherit"))
        assert_not valid?(shape("rect", x: 8))
        assert_not valid?(shape("rect", x: nil))
      end

      test "AV-09 — huit niveaux au plus : une forme au 9ᵉ niveau rend tout son arbre invalide" do
        assert valid?(nested(7))
        assert_not valid?(nested(8))
        assert_not valid?(RECT, depth: 9)
        assert valid?(RECT, depth: 8)
        assert_not valid?(RECT, depth: 0)
      end

      test "le format est exact : trois clés en chaînes, des attributs en table, des enfants en liste, seul g en a" do
        assert_not valid?(RECT.merge("children" => [ PATH ]))
        assert_not valid?(RECT.except("children"))
        assert_not valid?(RECT.except("attributes"))
        assert_not valid?(RECT.merge("extra" => "x"))
        assert_not valid?(RECT.transform_keys(&:to_sym))
        assert_not valid?(RECT.merge("attributes" => [ [ "x", "1" ] ]))
        assert_not valid?(shape("g").merge("children" => {}))
        assert_not valid?(RECT.merge("name" => nil))
        assert_not valid?(RECT.merge("name" => :rect))
        [ nil, "rect", [ RECT ], 42 ].each { assert_not valid?(it), it.inspect }
      end
    end
  end
end

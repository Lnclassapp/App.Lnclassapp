require "test_helper"

module Communication
  # UDR-0071 §3.3 : la bibliothèque fermée des huit illustrations d'annonce. Chacune est un SVG décoratif de 64 unités,
  # en aplats, dont les couleurs ne viennent que des tokens (UDR-0005), sans personnage ni texte.
  # ADR-0081 §4.3, UDR-0075 §3.2 : une illustration de l'équipe est reconstruite par le constructeur de balises, depuis
  # ses formes revérifiées sur la liste blanche ; elle n'est jamais insérée telle qu'elle a été stockée.
  class IllustrationsHelperTest < ActionView::TestCase
    KEYS = Entities::Communication::Message::ILLUSTRATIONS
    TOKENS = %w[fill-white fill-brand fill-brand-strong fill-school fill-teacher fill-gold fill-success fill-error].freeze
    # Les tons de chaque composition, tels que l'UDR les décrit.
    COMPOSITIONS = {
      "info" => %w[fill-brand fill-white],
      "calendar" => %w[fill-white fill-error fill-school fill-success],
      "homework" => %w[fill-white fill-brand fill-gold fill-school],
      "sheets" => %w[fill-brand-strong fill-white fill-brand fill-success],
      "exam" => %w[fill-white fill-teacher fill-school],
      "meeting" => %w[fill-school fill-teacher fill-brand fill-gold],
      "celebration" => %w[fill-gold fill-teacher fill-brand],
      "holidays" => %w[fill-gold fill-brand fill-brand-strong]
    }.freeze
    LABELS = %w[Information Date Devoirs Fiches Examen Réunion Félicitations Congés].freeze
    SHAPES = "circle, ellipse, rect, path, polygon, polyline, line"

    def svg(key, **) = Nokogiri::HTML5.fragment(announcement_illustration(key, **).to_s).at_css("svg")
    def source(key) = Rails.root.join("app/views/communication/messages/illustrations/_#{key}.html.erb").read

    test "les huit clés de la liste fermée rendent chacune un SVG décoratif de 64 unités, à la classe demandée" do
      KEYS.each do |key|
        node = svg(key, class: "size-16")

        assert_equal [ "0 0 64 64", "true", "false", "size-16" ], [ node["viewBox"], node["aria-hidden"], node["focusable"], node["class"] ], key
        assert_operator node.css(SHAPES).size, :>=, 2, key
      end
    end

    test "chaque forme porte un seul token de couleur, et chaque illustration les tons de sa composition" do
      KEYS.each do |key|
        fills = svg(key).css(SHAPES).map { it["class"] }

        assert(fills.all? { TOKENS.include?(it) }, "#{key} : #{fills.uniq - TOKENS}")
        assert_equal COMPOSITIONS.fetch(key).sort, fills.uniq.sort, key
      end
    end

    test "aucune couleur hors tokens : ni attribut fill ou stroke, ni style, ni #hex, ni texte dessiné" do
      KEYS.each do |key|
        code = source(key)

        assert_no_match(/\s(fill|stroke|style|color)=/, code, key)
        assert_no_match(/#\h{3,8}\b/, code, key)
        assert_no_match(/<(text|title|image|foreignObject)\b/, code, key)
        assert_match(/\A<%# 🌐 UI · communication\/messages\/illustrations\/_#{key} /, code, key)
      end
    end

    test "sans classe, le SVG n'en porte aucune ; une clé peut être un symbole" do
      node = svg(:info)

      assert_nil node["class"]
      assert_equal "true", node["aria-hidden"]
    end

    test "une clé inconnue ou absente lève ArgumentError en la nommant" do
      error = assert_raises(ArgumentError) { announcement_illustration("rocket") }

      assert_match "rocket", error.message
      assert_raises(ArgumentError) { announcement_illustration(nil) }
      assert_raises(ArgumentError) { announcement_illustration("../../layouts/application") }
    end

    test "chaque illustration a son libellé, dans l'ordre de l'UDR" do
      assert_equal LABELS, KEYS.map { I18n.t("communication.illustrations.#{it}") }
    end

    ILLUSTRATION = Entities::Communication::Illustration
    RECT = { "name" => "rect", "attributes" => { "x" => "8", "y" => "8", "width" => "48", "height" => "48", "rx" => "6" },
             "children" => [] }.freeze
    PATH = { "name" => "path", "attributes" => { "d" => "M4 4h56v56H4z", "fill-rule" => "evenodd" }, "children" => [] }.freeze
    GROUP = { "name" => "g", "attributes" => { "transform" => "translate(2,2)" },
              "children" => [ { "name" => "circle", "attributes" => { "cx" => "32", "cy" => "32", "r" => "8" }, "children" => [] } ] }.freeze
    # Ce qu'un rendu ne doit jamais laisser passer, quelle que soit la forme stockée.
    FORBIDDEN = /script|onload|onerror|href|foreignObject|<image|<use|<style|style=|javascript|alert|url\(|fill=|<a\b/i

    def team(shapes, view_box: "0 0 64 64", retired_at: nil)
      ILLUSTRATION.new(id: 1, public_id: "abcdefghijkmno", name: "Bus scolaire", view_box:, shapes:, created_by_id: 1, retired_at:)
    end

    def shape(name, children: [], **attributes)
      { "name" => name, "attributes" => attributes.transform_keys { it.to_s.tr("_", "-") }, "children" => children }
    end

    def nested(levels, leaf = RECT) = levels.times.reduce(leaf) { |child, _| shape("g", children: [ child ]) }

    def drawn(shapes, **) = announcement_illustration(team(shapes, **), class: "size-16").to_s

    test "AV-09 — une illustration de l'équipe est reconstruite : <svg> décoratif d'une seule couleur, formes de la liste blanche" do
      assert_equal '<svg viewBox="0 0 64 64" aria-hidden="true" focusable="false" class="size-16 fill-brand-strong">' \
                   '<rect x="8" y="8" width="48" height="48" rx="6" />' \
                   '<path d="M4 4h56v56H4z" fill-rule="evenodd" />' \
                   '<g transform="translate(2,2)"><circle cx="32" cy="32" r="8" /></g></svg>',
                   drawn([ RECT, PATH, GROUP ])
    end

    test "sans classe, le SVG porte la seule couleur du thème ; une illustration retirée reste rendue (AV-10)" do
      node = Nokogiri::HTML5.fragment(announcement_illustration(team([ RECT ], retired_at: Time.current)).to_s).at_css("svg")

      assert_equal [ "fill-brand-strong", "0 0 64 64", 1 ], [ node["class"], node["viewBox"], node.css("rect").size ]
    end

    test "AV-08 — une illustration créée par fabrique, relue par son repository, se rend en SVG reconstruit" do
      row = create_illustration(name: "Bus scolaire", created_by: create_team_member(second_factor: false))
      stored = Repositories::Communication::IllustrationRepository.new.find_by_public_id(public_id: row.public_id)

      node = Nokogiri::HTML5.fragment(announcement_illustration(stored, class: "size-12").to_s).at_css("svg")

      assert_equal [ "0 0 64 64", "true", "false", "size-12 fill-brand-strong" ],
                   [ node["viewBox"], node["aria-hidden"], node["focusable"], node["class"] ]
      assert_equal row.shapes.size, node.element_children.size
      assert_equal row.shapes.first["attributes"], node.element_children.first.attributes.transform_values(&:value)
    end

    test "AV-09 — une forme piégée n'est jamais rendue : script, onload, d qui s'échappe, href, profondeur de 9" do
      traps = [
        shape("script", children: []),
        { "name" => "script", "attributes" => {}, "children" => [], "text" => "alert(1)" },
        shape("g", children: [ RECT, shape("script") ]),
        RECT.merge("attributes" => RECT["attributes"].merge("onload" => "alert(1)")),
        shape("path", d: 'M0 0"><script>alert(1)</script>'),
        shape("path", d: "M0 0", href: "https://evil.example/x.svg"),
        shape("g", "xlink:href": "#a", children: [ RECT ]),
        nested(8),
        shape("foreignObject", children: [ shape("rect") ]),
        shape("image", href: "javascript:alert(1)"),
        shape("use", href: "#a"),
        RECT.merge("attributes" => RECT["attributes"].merge("style" => "fill:url(#x)")),
        RECT.merge("attributes" => RECT["attributes"].merge("fill" => "red")),
        shape("a", href: "javascript:alert(1)", children: [ RECT ]),
        "<script>alert(1)</script>",
        nil
      ]

      html = drawn([ PATH, *traps, nested(7) ])

      assert_no_match FORBIDDEN, html
      node = Nokogiri::HTML5.fragment(html).at_css("svg")
      assert_equal %w[path g], node.element_children.map(&:name)
      assert_equal 8, node.css("g, rect").size
      assert_equal "", drawn(traps).delete_prefix('<svg viewBox="0 0 64 64" aria-hidden="true" focusable="false" class="size-16 fill-brand-strong">').delete_suffix("</svg>")
    end

    test "AV-09 — une viewBox qui s'échappe est omise, et des formes qui ne sont pas une liste ne rendent rien" do
      escaped = drawn([ RECT ], view_box: '0 0 64 64" onload="alert(1)')

      assert_no_match FORBIDDEN, escaped
      assert_equal '<svg aria-hidden="true" focusable="false" class="size-16 fill-brand-strong"><rect x="8" y="8" width="48" height="48" rx="6" /></svg>', escaped
      assert_equal '<svg viewBox="0 0 64 64" aria-hidden="true" focusable="false" class="size-16 fill-brand-strong"></svg>',
                   drawn({ "name" => "script", "attributes" => {}, "children" => [] })
      assert_equal '<svg viewBox="0 0 64 64" aria-hidden="true" focusable="false" class="size-16 fill-brand-strong"></svg>', drawn(nil)
      assert_equal '<svg viewBox="0 0 64 64" aria-hidden="true" focusable="false" class="size-16 fill-brand-strong"></svg>',
                   drawn("<script>alert(1)</script>")
    end

    test "le rendu ne marque jamais de texte comme sûr et ne nomme une balise que depuis la liste blanche" do
      code = Rails.root.join("app/helpers/communication/illustrations_helper.rb").read

      assert_no_match(/html_safe|\braw\b|safe_concat|\.send\(|instance_eval|<%=|#\{.*shape/, code)
      assert_match(/ELEMENTS/, code)
      assert_match(/valid_shape\?/, code)
    end
  end
end

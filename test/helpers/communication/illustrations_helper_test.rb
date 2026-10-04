require "test_helper"

module Communication
  # UDR-0056 §3.3 : la bibliothèque fermée des huit illustrations d'annonce. Chacune est un SVG décoratif de 64 unités,
  # en aplats, dont les couleurs ne viennent que des tokens (UDR-0005), sans personnage ni texte.
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
  end
end

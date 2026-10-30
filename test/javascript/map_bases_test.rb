require "test_helper"

# ADR figures-des-matieres-de-3eme §4.2, §4.3 et §7 : les fonds de carte (lib/figures/maps/*.js, générés par script/contenus/fonds_de_carte.rb)
# portent exactement les identifiants de FigureCatalogs, pèsent 150 Ko au plus et ne contiennent que des chemins SVG sûrs.
class MapBasesTest < ActiveSupport::TestCase
  MAPS = Rails.root.join("app/javascript/lib/figures/maps")
  BASES = Entities::Catalog::FigureCatalogs::MAP_BASES.keys.freeze
  SAFE_PATH = /\AM[-\d. ]+(?:l[-\d. ]+)?z(?:M[-\d. ]+(?:l[-\d. ]+)?z)*\z/
  VIEWBOXES = { "cote_d_ivoire" => [ 640, 640 ], "africa" => [ 640, 640 ], "world" => [ 640, 360 ] }.freeze

  def source(base) = MAPS.join("#{base}.js").read

  def block(base, name) = source(base)[/export const #{name} = \{\n(.*?)\n\}/m, 1].to_s

  def area_entries(base) = block(base, "AREAS").lines(chomp: true).map { it.match(/\A  (\w+): \{ name: "(.+)", d: "(.+)" \},\z/) or flunk("#{base}: ligne d'AREAS illisible : #{it}") }

  def place_entries(base)
    block(base, "PLACES").lines(chomp: true).map { it.match(/\A  (\w+): \{ name: "(.+)", x: (-?[\d.]+), y: (-?[\d.]+) \},\z/) or flunk("#{base}: ligne de PLACES illisible : #{it}") }
  end

  def continents(base)
    block(base, "CONTINENTS").lines(chomp: true).to_h { |line| line.match(/\A  (\w+): (\[.*\]),\z/).then { |m| [ m[1], JSON.parse(m[2]) ] } }
  end

  test "the closed list has exactly the three bases of the lot" do
    assert_equal VIEWBOXES.keys.sort, BASES.sort
    assert_equal VIEWBOXES.keys.sort, Dir[MAPS.join("*.js")].map { File.basename(it, ".js") }.sort
  end

  BASES.each do |base|
    test "#{base}: the areas are exactly those of FigureCatalogs (a continent colours its countries)" do
      drawn = area_entries(base).map { it[1] }
      named = base == "world" ? continents(base).keys : []

      assert_equal Entities::Catalog::FigureCatalogs.areas(base).sort, (drawn + named).sort
      assert_equal drawn.uniq, drawn, "une aire dessinée deux fois"
    end

    test "#{base}: the places are exactly those of FigureCatalogs and lie inside the frame" do
      places = place_entries(base)
      width, height = VIEWBOXES.fetch(base)

      assert_equal Entities::Catalog::FigureCatalogs.places(base).sort, places.map { it[1] }.sort
      assert(places.all? { it[3].to_f.between?(0, width) && it[4].to_f.between?(0, height) }, "un lieu hors du cadre")
      assert(places.all? { it[2].strip == it[2] && it[2].present? }, "un nom de lieu vide")
    end

    test "#{base}: every area has a French name and every path is plain absolute-then-relative SVG" do
      area_entries(base).each do |entry|
        assert entry[2].present?, "#{base}.#{entry[1]} : nom vide"
        assert_match(/\A[MLZmlz0-9 .,-]+\z/, entry[3], "#{base}.#{entry[1]} : caractère interdit dans d")
        assert_match SAFE_PATH, entry[3], "#{base}.#{entry[1]} : chemin mal formé"
      end
      source(base)[/export const OUTLINE = \[\n?(.*?)\n?\]\n/m, 1].to_s.scan(/"([^"]+)"/).flatten.each do |d|
        assert_match SAFE_PATH, d, "#{base} : tracé OUTLINE mal formé"
      end
    end

    test "#{base}: weighs 150 KB at most, carries its HITL header and declares its frame" do
      assert_operator MAPS.join("#{base}.js").size, :<=, 150 * 1024
      head = source(base).lines.first(3)

      assert head[0].start_with?("// ⚡ FRONT · lib/figures/maps/#{base}"), head[0]
      assert head[1].start_with?("// Rôle : "), head[1]
      assert head[2].start_with?("// ADR  : "), head[2]
      assert_includes source(base), "export const VIEWBOX = [#{VIEWBOXES.fetch(base).join(', ')}]"
    end
  end

  test "geoBoundaries asks for its attribution under the legend, the Natural Earth bases do not" do
    assert_includes source("cote_d_ivoire"), 'export const ATTRIBUTION = "Districts : geoBoundaries, CC BY 4.0"'
    assert_includes source("africa"), 'export const ATTRIBUTION = ""'
    assert_includes source("world"), 'export const ATTRIBUTION = ""'
  end

  test "the continents of the world colour countries that exist, none of them twice" do
    members = continents("world")
    countries = area_entries("world").map { it[1] }

    assert_equal %w[africa asia europe north_america oceania south_america], members.keys.sort
    assert_empty members.values.flatten - countries
    assert_equal members.values.flatten.uniq, members.values.flatten
    assert_includes members.fetch("africa"), "civ"
  end

  test "the natural zones of Côte d'Ivoire are drawn and the districts keep their accents" do
    names = area_entries("cote_d_ivoire").to_h { [ it[1], it[2] ] }

    assert_equal "Forêt dense", names.fetch("dense_forest")
    assert_equal "Montagnes de l'Ouest", names.fetch("mountain_west")
    assert_equal "Vallée du Bandama", names.fetch("vallee_du_bandama")
    assert_equal "Comoé", names.fetch("comoe")
    assert_equal "Sassandra-Marahoué", names.fetch("sassandra_marahoue")
  end
end

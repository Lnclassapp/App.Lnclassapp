require "test_helper"

# ADR-0116 (fiche de révision, figures paramétrées) §4.2 et menace : les modules de figures sont ceux des sortes de la liste fermée,
# créent leurs nœuds par createElementNS et textContent (jamais innerHTML), et ne portent aucune couleur en dur.
class FiguresStructureTest < ActiveSupport::TestCase
  LIB = Rails.root.join("app/javascript/lib/figures")
  CONTROLLER = Rails.root.join("app/javascript/controllers/figure_controller.js")
  SUPPORT = %w[svg].freeze
  SOURCES = Dir[LIB.join("*.js")].freeze
  MAPS = Dir[LIB.join("maps/*.js")].freeze
  MAP_MAX_BYTES = 150 * 1024

  test "every module is a kind of the closed list or the shared svg helper" do
    names = SOURCES.map { File.basename(it, ".js") }

    assert_empty names - Entities::Catalog::FigureKinds::NAMES - SUPPORT
  end

  test "the controller whitelists exactly the kinds of the closed list" do
    listed = CONTROLLER.read[/KINDS\s*=\s*\[([^\]]*)\]/, 1].scan(/"([a-z_]+)"/).flatten

    assert_equal Entities::Catalog::FigureKinds::NAMES.sort, listed.sort
  end

  test "the sliders may only set the top-level params that FigureKinds declares adjustable" do
    block = CONTROLLER.read[/RANGE_PARAMS\s*=\s*\{(.*?)\n\}/m, 1]
    listed = block.scan(/(\w+):\s*\[([^\]]*)\]/).to_h { |kind, names| [ kind, names.scan(/"(\w+)"/).flatten ] }
    declared = Entities::Catalog::FigureKinds::ALL.transform_values { |kind| kind.adjustable.to_a }

    assert_equal declared, listed
  end

  test "the kinds of this lot have their module" do
    %w[geometry number_line optics molecule].each { assert_includes SOURCES.map { |path| File.basename(path, ".js") }, it }
  end

  test "the controller announces what the figure says, not only the label of the slider" do
    source = CONTROLLER.read

    assert_match(/this\.spoken/, source)
    assert_no_match(/setTimeout/, LIB.join("molecule.js").read)
  end

  test "a map base weighs 150 KB at most" do
    assert_empty MAPS.select { File.size(it) > MAP_MAX_BYTES }.map { File.basename(it) }
  end

  test "no figure code writes markup or loads a resource" do
    (SOURCES + MAPS + [ CONTROLLER.to_s ]).each do |path|
      source = File.read(path)

      assert_no_match(/innerHTML|outerHTML|insertAdjacentHTML|document\.write|eval\(|new Function/, source, path)
      assert_no_match(%r{https?://(?!www\.w3\.org/2000/svg)}, source, path)
    end
  end

  test "no hexadecimal, rgb or named colour: colours come from the CSS variables" do
    (SOURCES + MAPS).each do |path|
      source = File.read(path)

      assert_no_match(/#[0-9a-fA-F]{3,8}\b/, source, path)
      assert_no_match(/\b(?:rgba?|hsla?|oklch)\(/, source, path)
      assert_no_match(/(?:stroke|fill|color)["']?\s*[:=,]\s*["'](?:red|blue|green|black|white|gray|grey|orange|purple)["']/, source, path)
    end
  end

  test "svg nodes are made with createElementNS and text with textContent" do
    svg = LIB.join("svg.js").read

    assert_includes svg, "createElementNS"
    assert_includes svg, "textContent"
  end
end

require "test_helper"

# ADR-0116 §4.2 et ADR « figures des matières de 3ème » (plate) : la planche légendée et ses modules de dessin créent leurs nœuds par
# createElementNS et textContent, ne chargent aucune ressource, ne portent aucune couleur en dur, et déclarent exactement les parties du PRD.
class PlatesStructureTest < ActiveSupport::TestCase
  LIB = Rails.root.join("app/javascript/lib/figures")
  PLATES_DIR = LIB.join("plates")
  INDEX = PLATES_DIR.join("index.js")
  MODULES = Dir[PLATES_DIR.join("*.js")].reject { File.basename(it) == "index.js" }.freeze
  SOURCES = ([ LIB.join("plate.js").to_s, INDEX.to_s ] + MODULES).freeze

  # PRD du chantier contenus-3e-svt, §5 (le Lot D remplacera cette table par la parité avec FigureCatalogs::PLATES).
  PARTS = {
    "digestive_system" => %w[mouth salivary_glands oesophagus stomach liver gallbladder pancreas small_intestine large_intestine rectum anus],
    "blood_smear" => %w[red_blood_cell neutrophil lymphocyte monocyte platelet plasma],
    "heart" => %w[right_atrium left_atrium right_ventricle left_ventricle septum aorta pulmonary_artery superior_vena_cava inferior_vena_cava pulmonary_veins tricuspid_valve mitral_valve],
    "double_circulation" => %w[right_heart left_heart lungs organs pulmonary_artery pulmonary_veins aorta vena_cava],
    "female_reproductive_system" => %w[ovary oviduct infundibulum uterus endometrium cervix vagina],
    "hiv_virus" => %w[envelope gp120 gp41 matrix capsid rna reverse_transcriptase],
    "soil_profile" => %w[litter humus_horizon accumulation_horizon weathered_rock bedrock roots],
    "root_hairs" => %w[collar main_root lateral_root root_hair_zone elongation_zone root_cap root_hair soil_particle soil_water]
  }.freeze

  test "the plate module and the eight plates exist" do
    assert_path_exists LIB.join("plate.js")
    assert_path_exists INDEX
    assert_equal PARTS.keys.sort, MODULES.map { File.basename(it, ".js") }.sort
  end

  test "no plate code writes markup or loads a resource" do
    SOURCES.each do |path|
      source = File.read(path)

      assert_no_match(/innerHTML|outerHTML|insertAdjacentHTML|document\.write|eval\(|new Function/, source, path)
      assert_no_match(%r{https?://(?!www\.w3\.org/2000/svg)}, source, path)
    end
  end

  test "no hexadecimal, rgb, hsl, oklch or named colour: colours come from the COLOR names" do
    SOURCES.each do |path|
      source = File.read(path)

      assert_no_match(/#[0-9a-fA-F]{3,8}\b/, source, path)
      assert_no_match(/\b(?:rgba?|hsla?|oklch)\(/, source, path)
      assert_no_match(/(?:stroke|fill|color)["']?\s*[:=,]\s*["'](?:red|blue|green|black|white|gray|grey|orange|purple|yellow|pink|brown)["']/, source, path)
    end
  end

  test "every module of plates/ is imported and listed in PLATES, and conversely" do
    index = INDEX.read
    imported = index.scan(%r{from\s+"\./([a-z_]+)"}).flatten
    listed = index[/PLATES\s*=\s*\{([^}]*)\}/m, 1].to_s.scan(/[a-z_]+/)

    assert_equal MODULES.map { File.basename(it, ".js") }.sort, imported.sort
    assert_equal imported.sort, listed.sort
  end

  test "every module declares its TITLE, its PARTS and its draw" do
    MODULES.each do |path|
      source = File.read(path)

      assert_match(/export const TITLE\s*=/, source, path)
      assert_match(/export const PARTS\s*=/, source, path)
      assert_match(/export function draw\(/, source, path)
    end
  end

  test "each plate declares exactly the parts of the PRD, in order" do
    PARTS.each do |plate, expected|
      block = PLATES_DIR.join("#{plate}.js").read[/export const PARTS\s*=\s*\{(.*?)\n\}/m, 1]
      declared = block.scan(/^\s*([a-z_0-9]+):\s*\{\s*name:/).flatten

      assert_equal expected, declared, plate
    end
  end

  test "every drawn part carries data-part and no part is drawn that is not declared" do
    PARTS.each do |plate, expected|
      source = PLATES_DIR.join("#{plate}.js").read
      drawn = source.scan(/(?:part|tube|vessel)\(\s*"([a-z_0-9]+)"/).flatten.uniq

      assert_empty expected - drawn, "#{plate}: parties non dessinées"
      assert_empty drawn - expected, "#{plate}: parties dessinées mais non déclarées"
    end
  end

  test "plate.js builds nodes with the shared helpers and writes text through them" do
    source = LIB.join("plate.js").read

    assert_match(/data-plate/, source)
    assert_match(/data-label/, source)
    assert_match(/data-highlight/, source)
    assert_match(/throw new Error/, source)
  end
end

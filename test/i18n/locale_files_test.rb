require "test_helper"

# Every French locale file lives under `fr:`, defines each key once, and speaks the UDR-0007 vocabulary.
class LocaleFilesTest < ActiveSupport::TestCase
  FILES = Rails.root.glob("config/locales/**/*.fr.yml").freeze
  FORBIDDEN = /(?<![[:alpha:]])(habilet|notions? clés?|leçon|quiz|essai|platine|médaille|trophée)/i
  # UDR-0007, amendement du 2026-09-30 : le titre de la liste des fiches d'un cours, décidé par le porteur. « leçon » y
  # désigne le cours parent, pas la fiche ; seule cette valeur exacte, sous ces clés, est admise.
  ALLOWED = {
    "fr.catalog.courses.show.essentials_title" => "Essentielles de la leçon",
    "fr.classroom.classroom_courses.show.essentials_title" => "Essentielles de la leçon"
  }.freeze

  test "the French locale files exist" do
    assert_operator FILES.size, :>=, 6
  end

  test "every French file sits under fr:" do
    FILES.each do |path|
      assert_equal [ "fr" ], YAML.load_file(path).keys, "#{relative(path)} doit n'avoir que la racine fr:"
    end
  end

  test "no key is written twice in the same file" do
    FILES.each do |path|
      assert_empty duplicates(Psych.parse_file(path).root), "clés en double dans #{relative(path)}"
    end
  end

  test "no translation is defined by two files" do
    owners = Hash.new { |hash, key| hash[key] = [] }
    FILES.each { |path| leaves(YAML.load_file(path)).each { owners[it] << relative(path) } }

    assert_empty owners.select { |_, paths| paths.size > 1 }
  end

  # The import report shows each error by its code (teams/imports/_import_errors): a code without a message would
  # print « translation missing » to the team.
  test "every import error code has its French message" do
    missing = Entities::Catalog::ImportError::CODES.reject { I18n.exists?("teams.imports.error_codes.#{it}", :fr) }

    assert_empty missing
  end

  test "no term forbidden by UDR-0007" do
    offences = FILES.flat_map do |path|
      leaves(YAML.load_file(path), values: true).filter_map do |key, value|
        "#{relative(path)} #{key}" if value.to_s.match?(FORBIDDEN) && ALLOWED[key] != value
      end
    end

    assert_empty offences
  end

  test "the vocabulary pattern catches what it must" do
    [ "Habileté", "Notion clé", "notions clés", "Leçon", "Quiz", "Essai", "Platine", "Médaille", "Trophée" ].each do |term|
      assert_match FORBIDDEN, term
    end
    assert_no_match FORBIDDEN, "Fiche essentielle"
  end

  test "the UDR-0007 exception is the list title alone, with its exact wording" do
    assert(ALLOWED.values.all? { it.match?(FORBIDDEN) })
    assert_equal [ "Essentielles de la leçon" ], ALLOWED.values.uniq
    ALLOWED.each { |key, value| assert_equal value, I18n.t(key.delete_prefix("fr."), locale: :fr) }
  end

  private

  def relative(path) = path.relative_path_from(Rails.root).to_s

  def duplicates(node)
    return [] unless node.respond_to?(:children) && node.children

    own = if node.is_a?(Psych::Nodes::Mapping)
      keys = node.children.each_slice(2).map { |key, _| key.value }
      keys.tally.select { |_, count| count > 1 }.keys
    end
    Array(own) + node.children.flat_map { duplicates(it) }
  end

  def leaves(hash, prefix = nil, values: false)
    hash.flat_map do |key, value|
      path = [ prefix, key ].compact.join(".")
      next leaves(value, path, values:) if value.is_a?(Hash)

      [ values ? [ path, value ] : path ]
    end
  end
end

require "test_helper"

# Every French locale file lives under `fr:`, defines each key once, and speaks the UDR-0007 vocabulary.
class LocaleFilesTest < ActiveSupport::TestCase
  FILES = Rails.root.glob("config/locales/**/*.fr.yml").freeze
  FORBIDDEN = /(?<![[:alpha:]])(habilet|notions? clés?|leçon|quiz|essai|platine|médaille|trophée)/i
  # V0 screens written before UDR-0007: their wording belongs to the landing lot (A4) and the style guide.
  LEGACY_VOCABULARY = %w[config/locales/homepage/index.fr.yml config/locales/design/index.fr.yml].freeze

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

  test "no term forbidden by UDR-0007" do
    offences = FILES.reject { LEGACY_VOCABULARY.include?(relative(it)) }.flat_map do |path|
      leaves(YAML.load_file(path), values: true).filter_map { |key, value| "#{relative(path)} #{key}" if value.to_s.match?(FORBIDDEN) }
    end

    assert_empty offences
  end

  test "the vocabulary pattern catches what it must" do
    [ "Habileté", "Notion clé", "notions clés", "Leçon", "Quiz", "Essai", "Platine", "Médaille", "Trophée" ].each do |term|
      assert_match FORBIDDEN, term
    end
    assert_no_match FORBIDDEN, "Fiche essentielle"
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

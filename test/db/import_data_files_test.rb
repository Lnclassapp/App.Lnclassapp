require "test_helper"

# DR-11 (ADR-0066): the delivered import files agree with each other. The 41 DRENA of drenas-2026.json,
# keyed by Entities::School::Drena.slug_for, are exactly the DRENA cited by the 3 851 schools of
# etablissements-2026.json, so importing the first then the second yields no unknown_drena error.
class ImportDataFilesTest < ActiveSupport::TestCase
  DIR = Rails.root.join("db/seeds/data/imports")
  DRENAS_PATH = DIR.join("drenas-2026.json")
  SCHOOLS_PATH = DIR.join("etablissements-2026.json")

  # Parsed once per run: the schools file is several hundred kilobytes.
  def self.document(path) = (@documents ||= {})[path] ||= JSON.parse(path.read)

  def drenas = self.class.document(DRENAS_PATH)
  def schools = self.class.document(SCHOOLS_PATH)
  def drena_slugs = drenas["drenas"].map { Entities::School::Drena.slug_for(it["name"]) }
  def cited_drenas = schools["schools"].map { it["drena"] }.to_set

  def validate(format, document) = Repositories::Catalog::ImportSchemaValidator.new.validate(format:, version: 1, document:)

  test "drenas-2026.json est valide pour le schéma lnclass.drenas v1" do
    assert_empty validate("lnclass.drenas", drenas)
  end

  test "drenas-2026.json donne 41 slugs distincts, aucun nul" do
    assert_equal 41, drenas["drenas"].size
    assert_not_includes drena_slugs, nil
    assert_equal 41, drena_slugs.uniq.size
  end

  test "etablissements-2026.json est valide pour le schéma lnclass.schools v1 et compte 3 851 écoles" do
    assert_empty validate("lnclass.schools", schools)
    assert_equal 3851, schools["schools"].size
  end

  test "les DRENA citées par les écoles sont exactement les slugs de drenas-2026.json" do
    assert_equal drena_slugs.to_set, cited_drenas
  end

  test "chaque école cite un slug préfixé drena-" do
    assert_empty cited_drenas.reject { it.to_s.start_with?("#{Entities::School::Drena::SLUG_PREFIX}-") }
  end
end

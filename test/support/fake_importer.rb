# Adaptateur d'import factice (plan boucle-pedagogique, 0e.e2) : type « schools », éléments { "name" => … },
# clé = nom normalisé, écriture dans un tableau en mémoire. Échecs programmables par nom :
# `refused` simule un refus de la base (le lot est rejoué), `exploding` une panne imprévue.
class FakeImporter
  include UseCases::Catalog::Importer

  KIND = "schools"
  POLICY = Policies::School::ManageSchoolPolicy
  NAME_MAX = 150

  attr_reader :written, :writes

  def initialize(existing: [], refused: [], exploding: [], unknown_targets: [ "inconnue" ])
    @existing = existing.to_set { Entities::Shared::NaturalKey.normalize(it) }
    @refused = refused
    @exploding = exploding
    @unknown_targets = unknown_targets
    @written = []
    @writes = 0
  end

  def resolve_target(document:)
    return Shared::Result.failure(:not_found) if @unknown_targets.include?(document["drena"])

    Shared::Result.success(document["drena"])
  end

  def prepare(target:)
    Entities::Catalog::ImportContext.new(target:, existing_keys: @existing)
  end

  def validate_root(root:, path:, context:)
    name = root["name"].to_s.squish
    errors = []
    errors << Entities::Catalog::ImportError.new(path: "#{path}.name", code: "blank") if name.empty?
    errors << Entities::Catalog::ImportError.new(path: "#{path}.name", code: "too_long", params: { max: NAME_MAX }) if name.length > NAME_MAX
    Entities::Catalog::ImportItem.new(path:, key: Entities::Shared::NaturalKey.normalize(name), plan: { name: }, errors:)
  end

  # Tout le lot ou rien, comme une transaction.
  def write(items:, author_id:, at:)
    @writes += 1
    names = items.map { it.plan[:name] }
    raise "panne imprévue sur #{names.intersection(@exploding).first}" if names.intersect?(@exploding)
    raise FakeTransaction::Refused if names.intersect?(@refused)

    @written.concat(names)
    { imported: names.size, details: { "classrooms" => names.size * 2 } }
  end
end

# Job d'import factice : `FakeImporter` sur le moteur réel (rapport, fichier, transaction, audit), avec le schéma
# de test test/fixtures/files/import_schemas/fake.v1.json. `importer_options` programme l'adaptateur ;
# `with_fake_import_job` fait mettre ce job en file pour le type « schools ».
class FakeImportJob < Shared::ImportJob
  SCHEMAS = Rails.root.join("test/fixtures/files/import_schemas")

  # Le schéma de test s'appelle « fake » : le format du type (« lnclass.schools ») n'a pas encore le sien.
  FakeSchema = Data.define(:validator) do
    def validate(format:, version:, document:) = validator.validate(format: "fake", version:, document:)
  end

  class_attribute :importer_options, default: {}

  def adapter = @adapter ||= FakeImporter.new(**importer_options)

  private

  def schema_validator = FakeSchema.new(validator: Repositories::Catalog::ImportSchemaValidator.new(root: SCHEMAS))
end

module FakeImportJobHelper
  ActiveSupport::TestCase.include(self)

  def with_fake_import_job(**importer_options)
    jobs = Rails.configuration.x.import_jobs
    Rails.configuration.x.import_jobs = jobs.merge("schools" => "FakeImportJob").freeze
    FakeImportJob.importer_options = importer_options
    yield
  ensure
    Rails.configuration.x.import_jobs = jobs
    FakeImportJob.importer_options = {}
  end
end

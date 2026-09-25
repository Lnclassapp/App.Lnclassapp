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

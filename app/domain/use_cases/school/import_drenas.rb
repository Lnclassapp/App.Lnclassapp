# 🧠 DOMAINE · UseCases::School::ImportDrenas
# Rôle : adaptateur d'import des DRENA : chaque ligne ne porte que son nom, le slug drena-… en est tiré et sert de clé de doublon
# ADR  : 0039, 0066 · UDR : 0053
module UseCases
  module School
    class ImportDrenas
      include UseCases::Catalog::Importer

      KIND = "drenas"
      # Le moteur autorise l'auteur par le registre des types (ImportKind) ; c'est la même policy.
      POLICY = Policies::School::ManageSchoolPolicy
      PUBLIC_ID_LENGTH = 14

      def initialize(drenas:)
        @drenas = drenas
      end

      # Un import de DRENA n'a pas de cible.
      def resolve_target(document:)
        Shared::Result.success(nil)
      end

      # Clés de doublon : les slugs en base. Les noms pris servent à l'erreur taken.
      def prepare(target:)
        Entities::Catalog::ImportContext.new(target:, existing_keys: @drenas.ids_by_slug.keys.to_set,
                                             data: { taken_names: @drenas.taken_names })
      end

      # Une ligne dont le slug existe déjà est un doublon, que le moteur ignore : elle n'est jamais en erreur taken.
      def validate_root(root:, path:, context:)
        drena = Entities::School::Drena.new(name: root["name"])
        slug = Entities::School::Drena.slug_for(drena.name)
        error = name_error(drena, slug, "#{path}.name", context)
        return Entities::Catalog::ImportItem.new(path:, errors: [ error ]) if error

        Entities::Catalog::ImportItem.new(path:, key: slug,
                                          plan: { public_id: SecureRandom.base58(PUBLIC_ID_LENGTH), name: drena.name, slug: })
      end

      def write(items:, author_id:, at:)
        { imported: @drenas.insert_many(rows: items.map(&:plan), at:), details: {} }
      end

      private

      # → ImportError | nil ; une seule erreur par nom, la plus fondamentale.
      def name_error(drena, slug, path, context)
        drena.validate
        return error(path, "blank") if drena.errors.of_kind?(:name, :blank)
        return error(path, "too_long", max: Entities::School::Drena::NAME_MAX) if drena.errors.of_kind?(:name, :too_long)
        return error(path, "invalid_value", value: drena.name) if slug.nil?

        error(path, "taken", value: drena.name) if taken?(drena.name, slug, context)
      end

      def taken?(name, slug, context)
        !context.existing_keys.include?(slug) && context.data.fetch(:taken_names).include?(name)
      end

      def error(path, code, **params) = Entities::Catalog::ImportError.new(path:, code:, params:)
    end
  end
end

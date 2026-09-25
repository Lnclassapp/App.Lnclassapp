require "test_helper"

module UseCases
  module Catalog
    class UpdateMaterialTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      Material = Entities::Catalog::Material

      # Le slug est celui de l'entité reçue : le faux dépôt, comme le vrai, ne le recalcule jamais.
      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        def initialize(*materials)
          @materials = materials.index_by(&:id)
        end

        def find_material(slug:) = @materials.values.find { it.slug == slug }&.dup

        def update_material(material:)
          taken = @materials.values.any? { it.id != material.id && it.name == material.name }
          return Shared::Result.failure(:conflict, errors: { name: [ :taken ] }) if taken

          @materials[material.id] = material
          Shared::Result.success(material)
        end

        def stored(slug) = @materials.values.find { it.slug == slug }
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def initialize
          @events = []
        end

        def record(**event) = (@events << event) && true
      end

      setup do
        @taxonomy = FakeTaxonomy.new(Material.new(id: 203, slug: "svt", name: "SVT", shortname: "SVT", category: "science"),
                                     Material.new(id: 204, slug: "francais", name: "Français", shortname: "Fr", category: "literature"))
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def update(slug: "svt", actor: @team, **attributes)
        dto = Dtos::Catalog::MaterialInput.new(name: "SVT", shortname: "SVT", category: "science", **attributes)
        UpdateMaterial.new(taxonomy: @taxonomy, audit_log: @audit, policy: Policies::Catalog::ManageTaxonomyPolicy.new,
                           transaction: @transaction, clock: Clock.new(NOW)).call(actor:, slug:, dto:)
      end

      test "renommer garde le slug et la catégorie : le ton de la matière ne change pas" do
        result = update(name: "Sciences de la Vie et de la Terre")

        assert result.success?
        assert_equal [ 203, "svt", "Sciences de la Vie et de la Terre", "science" ],
                     [ result.value.id, result.value.slug, result.value.name, result.value.category ]
        assert_equal "science", @taxonomy.stored("svt").category
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "taxonomy.changed", actor_id: 7, at: NOW, subject_type: "Material", subject_id: 203,
                         metadata: { change: "updated", slug: "svt", changes: { "name" => [ "SVT", "Sciences de la Vie et de la Terre" ] } } } ],
                     @audit.events
      end

      test "changer la catégorie change le ton ; le nom et le slug restent" do
        result = update(category: "other", shortname: "Bio")

        assert_equal [ "svt", "SVT", "Bio", "other" ], [ result.value.slug, result.value.name, result.value.shortname, result.value.category ]
        assert_equal "other", @taxonomy.stored("svt").category
        assert_equal({ "shortname" => %w[SVT Bio], "category" => %w[science other] }, @audit.events.sole[:metadata][:changes])
      end

      test "hors de l'équipe : refus avant toute lecture, rien n'est écrit" do
        result = update(actor: Entities::Identity::Actor.new(user_id: 8, role: :student), category: "other")

        assert_equal :forbidden, result.code
        assert_equal "science", @taxonomy.stored("svt").category
        assert_equal 0, @transaction.calls
      end

      test "une matière inconnue : :not_found" do
        assert_equal :not_found, update(slug: "latin").code
        assert_equal 0, @transaction.calls
      end

      test "une saisie invalide : :invalid, la matière est intacte" do
        result = update(category: "", name: "a" * 41)

        assert_equal :invalid, result.code
        assert_equal %i[name category], result.errors.keys
        assert_equal "science", @taxonomy.stored("svt").category
        assert_equal 0, @transaction.calls
      end

      test "le nom d'une autre matière : :conflict, sans journal" do
        result = update(name: "Français")

        assert_equal [ :conflict, { name: [ :taken ] } ], [ result.code, result.errors ]
        assert_equal "SVT", @taxonomy.stored("svt").name
        assert_empty @audit.events
      end
    end
  end
end

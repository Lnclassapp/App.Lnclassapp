require "test_helper"

module UseCases
  module Catalog
    class CreateMaterialTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)

      # Nom et abrégé uniques, comme les index de la table ; le slug est dérivé du nom.
      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        attr_reader :stored

        def initialize(*materials)
          @stored = materials
        end

        def create_material(material:)
          taken = %i[name shortname].find { |field| @stored.any? { it.public_send(field) == material.public_send(field) } }
          return Shared::Result.failure(:conflict, errors: { taken => [ :taken ] }) if taken

          material.id = 300 + @stored.size
          material.slug = material.name.parameterize
          @stored << material
          Shared::Result.success(material)
        end
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
        @taxonomy = FakeTaxonomy.new(Entities::Catalog::Material.new(id: 201, slug: "francais", name: "Français",
                                                                     shortname: "Fr", category: "literature"))
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def create(actor: @team, **attributes)
        dto = Dtos::Catalog::MaterialInput.new(name: "SVT", shortname: "SVT", category: "science", **attributes)
        CreateMaterial.new(taxonomy: @taxonomy, audit_log: @audit, policy: Policies::Catalog::ManageTaxonomyPolicy.new,
                           transaction: @transaction, clock: Clock.new(NOW)).call(actor:, dto:)
      end

      test "crée la matière avec sa catégorie, dans une transaction, et l'inscrit au journal" do
        result = create

        assert result.success?
        material = result.value
        assert_equal [ "SVT", "SVT", "science", "svt" ], [ material.name, material.shortname, material.category, material.slug ]
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "taxonomy.changed", actor_id: 7, at: NOW, subject_type: "Material", subject_id: material.id,
                         metadata: { change: "created", slug: "svt" } } ], @audit.events
      end

      test "la casse saisie est gardée : « SVT » ne devient pas « Svt »" do
        assert_equal "SVT", create(name: "  SVT ").value.name
      end

      test "hors de l'équipe : refus, rien n'est écrit" do
        teacher = Entities::Identity::Actor.new(user_id: 8, role: :teacher)

        [ teacher, nil ].each do |actor|
          result = create(actor:)

          assert_equal :forbidden, result.code
        end
        assert_equal 1, @taxonomy.stored.size
        assert_empty @audit.events
        assert_equal 0, @transaction.calls
      end

      test "sans catégorie : :invalid, avec l'erreur sur la catégorie, et rien n'est écrit" do
        result = create(category: nil)

        assert_equal :invalid, result.code
        assert result.errors.key?(:category)
        assert_equal 1, @taxonomy.stored.size
        assert_equal 0, @transaction.calls
      end

      test "un nom ou un abrégé déjà pris : :conflict sur le champ, sans journal" do
        assert_equal({ name: [ :taken ] }, create(name: "Français", shortname: "FR2").errors)
        assert_equal({ shortname: [ :taken ] }, create(name: "Français langue", shortname: "Fr").errors)
        assert_equal :conflict, create(name: "Français").code
        assert_empty @audit.events
      end
    end
  end
end

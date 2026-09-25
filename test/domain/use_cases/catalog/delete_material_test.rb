require "test_helper"

module UseCases
  module Catalog
    class DeleteMaterialTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      Material = Entities::Catalog::Material

      # `referenced` : ids portés par un cours ou un profil enseignant ; jamais de suppression en cascade.
      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        attr_reader :materials

        def initialize(materials, referenced: [])
          @materials = materials
          @referenced = referenced
        end

        def find_material(slug:) = @materials.find { it.slug == slug }

        def delete_material(id:)
          return Shared::Result.failure(:conflict, errors: { base: [ :referenced ] }) if @referenced.include?(id)

          @materials.reject! { it.id == id }
          Shared::Result.success
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
        @taxonomy = FakeTaxonomy.new(
          [ Material.new(id: 203, slug: "svt", name: "SVT", shortname: "SVT", category: "science"),
            Material.new(id: 204, slug: "francais", name: "Français", shortname: "Fr", category: "literature") ],
          referenced: [ 204 ]
        )
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def delete(slug, actor: @team)
        DeleteMaterial.new(taxonomy: @taxonomy, audit_log: @audit, policy: Policies::Catalog::ManageTaxonomyPolicy.new,
                           transaction: @transaction, clock: Clock.new(NOW)).call(actor:, slug:)
      end

      test "supprime une matière vierge et l'inscrit au journal" do
        result = delete("svt")

        assert result.success?
        assert_equal %w[francais], @taxonomy.materials.map(&:slug)
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "taxonomy.changed", actor_id: 7, at: NOW, subject_type: "Material", subject_id: 203,
                         metadata: { change: "deleted", slug: "svt", name: "SVT" } } ], @audit.events
      end

      test "une matière portée par un cours ou un enseignant : :conflict avec la raison, rien n'est supprimé" do
        result = delete("francais")

        assert_equal [ :conflict, { base: [ :referenced ] } ], [ result.code, result.errors ]
        assert_equal %w[svt francais], @taxonomy.materials.map(&:slug)
        assert_empty @audit.events
      end

      test "hors de l'équipe : refus, rien n'est supprimé" do
        result = delete("svt", actor: Entities::Identity::Actor.new(user_id: 8, role: :teacher))

        assert_equal :forbidden, result.code
        assert_equal 2, @taxonomy.materials.size
        assert_equal 0, @transaction.calls
      end

      test "une matière inconnue : :not_found" do
        assert_equal :not_found, delete("latin").code
        assert_equal 0, @transaction.calls
      end
    end
  end
end

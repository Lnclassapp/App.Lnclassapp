require "test_helper"

module UseCases
  module Catalog
    class DeleteLevelTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      Level = Entities::Catalog::Level

      # Comme le repository : un niveau lié à une série, porté par une classe ou un cours n'est jamais supprimé.
      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        attr_reader :levels

        def initialize(levels, referenced_ids:)
          @levels = levels
          @referenced_ids = referenced_ids
        end

        def find_level(slug:) = @levels.find { it.slug == slug }

        def delete_level(id:)
          return Shared::Result.failure(:conflict, errors: { base: [ :referenced ] }) if @referenced_ids.include?(id)

          @levels = @levels.reject { it.id == id }
          Shared::Result.success
        end
      end

      class FakeAuditLog
        include Ports::Identity::AuditLogPort

        attr_reader :records

        def initialize
          @records = []
        end

        def record(**entry) = (@records << entry) && true
      end

      setup do
        @taxonomy = FakeTaxonomy.new([ Level.new(id: 1, slug: "6eme", name: "6ème", position: 1, cycle: "first"),
                                       Level.new(id: 2, slug: "tle", name: "Tle", position: 7, cycle: "second") ],
                                     referenced_ids: [ 2 ])
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def delete(slug: "6eme", actor: @team)
        DeleteLevel.new(taxonomy: @taxonomy, audit_log: @audit_log, transaction: @transaction,
                        policy: Policies::Catalog::ManageTaxonomyPolicy.new, clock: Clock.new(NOW))
                   .call(actor:, slug:)
      end

      test "l'équipe supprime un niveau que rien n'utilise, et le journal le garde" do
        result = delete

        assert result.success?
        assert_nil @taxonomy.find_level(slug: "6eme")
        assert_equal [ { action: "taxonomy.changed", actor_id: 7, at: NOW, subject_type: "Level", subject_id: 1,
                         metadata: { operation: "delete", slug: "6eme" } } ], @audit_log.records
        assert_equal 1, @transaction.calls
      end

      test "un niveau utilisé n'est jamais supprimé : conflit avec la raison, aucune cascade" do
        result = delete(slug: "tle")

        assert_equal [ :conflict, { base: [ :referenced ] } ], [ result.code, result.errors ]
        assert_equal "Tle", @taxonomy.find_level(slug: "tle").name
        assert_empty @audit_log.records
      end

      test "hors équipe, rien n'est supprimé, même un niveau inconnu" do
        teacher = Entities::Identity::Actor.new(user_id: 8, role: :teacher, school_id: 3)

        assert_equal :forbidden, delete(actor: teacher).code
        assert_equal :forbidden, delete(actor: nil, slug: "inconnu").code
        assert_equal 2, @taxonomy.levels.size
        assert_empty @audit_log.records
      end

      test "un niveau inconnu est introuvable" do
        assert_equal :not_found, delete(slug: "inconnu").code
        assert_equal 0, @transaction.calls
      end
    end
  end
end

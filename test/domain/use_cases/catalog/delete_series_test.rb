require "test_helper"

module UseCases
  module Catalog
    class DeleteSeriesTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)

      # Une série liée à un niveau, ou portée par une classe ou un cours, est référencée (ADR-0036).
      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        attr_reader :deleted

        def initialize(series, referenced:)
          @series = series
          @referenced = referenced
          @deleted = []
        end

        def find_series(slug:) = @series.find { it.slug == slug }

        def delete_series(id:)
          return Shared::Result.failure(:conflict, errors: { base: [ :referenced ] }) if @referenced.include?(id)

          @deleted << id
          Shared::Result.success
        end
      end

      class FakeAuditLog
        include Ports::Identity::AuditLogPort

        attr_reader :entries

        def initialize
          @entries = []
        end

        def record(**entry) = (@entries << entry) && true
      end

      setup do
        @taxonomy = FakeTaxonomy.new([ Entities::Catalog::Series.new(id: 1, slug: "d", name: "D"),
                                       Entities::Catalog::Series.new(id: 2, slug: "c", name: "C") ], referenced: [ 2 ])
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def delete(slug: "d", actor: @team)
        DeleteSeries.new(taxonomy: @taxonomy, audit_log: @audit_log, transaction: @transaction,
                         policy: Policies::Catalog::ManageTaxonomyPolicy.new, clock: Clock.new(NOW))
                    .call(actor:, slug:)
      end

      test "supprime une série vierge, la renvoie, et journalise taxonomy.changed" do
        result = delete

        assert result.success?
        assert_equal [ "d", "D" ], [ result.value.slug, result.value.name ]
        assert_equal [ 1 ], @taxonomy.deleted
        assert_equal [ { action: "taxonomy.changed", actor_id: 7, subject_type: "Series", subject_id: 1,
                         metadata: { change: "series.deleted", slug: "d" }, at: NOW } ], @audit_log.entries
        assert_equal 1, @transaction.calls
      end

      test "une série liée ou utilisée donne :conflict avec sa raison ; rien n'est supprimé ni journalisé" do
        result = delete(slug: "c")

        assert_equal :conflict, result.code
        assert_equal({ base: [ :referenced ] }, result.errors)
        assert_empty @taxonomy.deleted
        assert_empty @audit_log.entries
      end

      test "hors de l'équipe : :forbidden ; une série inconnue : :not_found" do
        teacher = Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 1)

        assert_equal :forbidden, delete(actor: teacher).code
        assert_equal :forbidden, delete(actor: nil).code
        assert_equal :not_found, delete(slug: "inconnue").code
        assert_empty @taxonomy.deleted
      end
    end
  end
end

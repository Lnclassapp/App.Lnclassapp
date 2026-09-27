require "test_helper"

module UseCases
  module Catalog
    class UnlinkLevelSeriesTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)

      # Un couple porté par une classe ou un cours ne se retire pas (ADR-0034, ADR-0036).
      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        attr_reader :pairs

        def initialize(pairs, used:)
          @pairs = pairs
          @used = used
        end

        def find_level(slug:) = { "tle" => Entities::Catalog::Level.new(id: 7, slug: "tle", name: "Tle") }[slug]
        def find_series(slug:) = { "d" => Entities::Catalog::Series.new(id: 105, slug: "d", name: "D") }[slug]

        def unlink(level_id:, series_id:)
          return Shared::Result.failure(:conflict, errors: { base: [ :referenced ] }) if @used.include?([ level_id, series_id ])

          @pairs.delete([ level_id, series_id ])
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
        @taxonomy = FakeTaxonomy.new([ [ 7, 105 ] ], used: [])
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def unlink(level_slug: "tle", series_slug: "d", actor: @team)
        UnlinkLevelSeries.new(taxonomy: @taxonomy, audit_log: @audit_log, transaction: @transaction,
                              policy: Policies::Catalog::ManageTaxonomyPolicy.new, clock: Clock.new(NOW))
                         .call(actor:, level_slug:, series_slug:)
      end

      test "retire un couple inutilisé, et journalise taxonomy.changed" do
        assert unlink.success?
        assert_empty @taxonomy.pairs
        assert_equal [ { action: "taxonomy.changed", actor_id: 7, subject_type: "Series", subject_id: 105,
                         metadata: { change: "level_series.unlinked", level: "tle", series: "d" }, at: NOW } ], @audit_log.entries
        assert_equal 1, @transaction.calls
      end

      test "un couple utilisé par une classe ou un cours est refusé avec sa raison, jamais en silence" do
        @taxonomy = FakeTaxonomy.new([ [ 7, 105 ] ], used: [ [ 7, 105 ] ])

        result = unlink

        assert_equal :conflict, result.code
        assert_equal({ base: [ :referenced ] }, result.errors)
        assert_equal [ [ 7, 105 ] ], @taxonomy.pairs
        assert_empty @audit_log.entries
      end

      test "hors de l'équipe : :forbidden ; un niveau ou une série inconnus : :not_found" do
        teacher = Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 1)

        assert_equal :forbidden, unlink(actor: teacher).code
        assert_equal :forbidden, unlink(actor: nil).code
        assert_equal :not_found, unlink(level_slug: "inconnu").code
        assert_equal :not_found, unlink(series_slug: "inconnue").code
        assert_equal [ [ 7, 105 ] ], @taxonomy.pairs
      end
    end
  end
end

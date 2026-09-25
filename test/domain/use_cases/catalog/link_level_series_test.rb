require "test_helper"

module UseCases
  module Catalog
    class LinkLevelSeriesTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)

      LEVELS = { "tle" => Entities::Catalog::Level.new(id: 7, slug: "tle", name: "Tle", cycle: "second"),
                 "6eme" => Entities::Catalog::Level.new(id: 1, slug: "6eme", name: "6ème", cycle: "first") }.freeze

      # Couple unique, comme l'index de level_series.
      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        attr_reader :pairs

        def initialize(pairs)
          @pairs = pairs
        end

        def find_level(slug:) = LEVELS[slug]
        def find_series(slug:) = { "d" => Entities::Catalog::Series.new(id: 105, slug: "d", name: "D") }[slug]

        def link(level_id:, series_id:, at:)
          return Shared::Result.failure(:conflict, errors: { base: [ :already_linked ] }) if @pairs.include?([ level_id, series_id ])

          @pairs << [ level_id, series_id, at ]
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
        @taxonomy = FakeTaxonomy.new([])
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def link(level_slug: "tle", series_slug: "d", actor: @team)
        LinkLevelSeries.new(taxonomy: @taxonomy, audit_log: @audit_log, transaction: @transaction,
                            policy: Policies::Catalog::ManageTaxonomyPolicy.new, clock: Clock.new(NOW))
                       .call(actor:, level_slug:, series_slug:)
      end

      test "lie la série au niveau, à l'heure de l'horloge, et journalise taxonomy.changed" do
        assert link.success?
        assert_equal [ [ 7, 105, NOW ] ], @taxonomy.pairs
        assert_equal [ { action: "taxonomy.changed", actor_id: 7, subject_type: "Series", subject_id: 105,
                         metadata: { change: "level_series.linked", level: "tle", series: "d" }, at: NOW } ], @audit_log.entries
        assert_equal 1, @transaction.calls
      end

      test "un couple déjà lié donne :conflict already_linked, sans journal" do
        @taxonomy = FakeTaxonomy.new([ [ 7, 105 ] ])

        result = link

        assert_equal :conflict, result.code
        assert_equal({ base: [ :already_linked ] }, result.errors)
        assert_empty @audit_log.entries
      end

      test "un niveau du premier cycle n'ouvre aucune série : :invalid, sans écriture ni journal" do
        result = link(level_slug: "6eme")

        assert_equal :invalid, result.code
        assert_equal({ base: [ :first_cycle ] }, result.errors)
        assert_empty @taxonomy.pairs
        assert_empty @audit_log.entries
        assert_equal 0, @transaction.calls
      end

      test "hors de l'équipe : :forbidden ; un niveau ou une série inconnus : :not_found" do
        teacher = Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 1)

        assert_equal :forbidden, link(actor: teacher).code
        assert_equal :forbidden, link(actor: nil).code
        assert_equal :not_found, link(level_slug: "inconnu").code
        assert_equal :not_found, link(series_slug: "inconnue").code
        assert_empty @taxonomy.pairs
        assert_empty @audit_log.entries
      end
    end
  end
end

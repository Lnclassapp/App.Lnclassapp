require "test_helper"

module UseCases
  module Catalog
    class UpdateSeriesTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)

      # Le slug est figé : update_series ne touche qu'au nom, qui reste unique.
      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        attr_reader :updated

        def initialize(series)
          @series = series
          @updated = []
        end

        def find_series(slug:) = @series.find { it.slug == slug }

        def update_series(series:)
          return Shared::Result.failure(:conflict, errors: { name: [ :taken ] }) if @series.any? { it.name == series.name && it.id != series.id }

          @updated << series
          Shared::Result.success(series)
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
                                       Entities::Catalog::Series.new(id: 2, slug: "c", name: "C") ])
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def update(slug: "d", name: "Série D", actor: @team)
        UpdateSeries.new(taxonomy: @taxonomy, audit_log: @audit_log, transaction: @transaction,
                         policy: Policies::Catalog::ManageTaxonomyPolicy.new, clock: Clock.new(NOW))
                    .call(actor:, slug:, dto: Dtos::Catalog::SeriesInput.new(name:))
      end

      test "renommer une série garde son slug, et journalise taxonomy.changed" do
        result = update

        assert result.success?
        assert_equal [ 1, "d", "Série D" ], [ result.value.id, result.value.slug, result.value.name ]
        assert_equal [ { action: "taxonomy.changed", actor_id: 7, subject_type: "Series", subject_id: 1,
                         metadata: { change: "series.updated", slug: "d" }, at: NOW } ], @audit_log.entries
        assert_equal 1, @transaction.calls
      end

      test "hors de l'équipe : :forbidden, sans rien écrire" do
        teacher = Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 1)

        assert_equal :forbidden, update(actor: teacher).code
        assert_equal :forbidden, update(actor: nil, slug: "inconnue").code
        assert_empty @taxonomy.updated
      end

      test "une série inconnue donne :not_found" do
        assert_equal :not_found, update(slug: "inconnue").code
        assert_empty @audit_log.entries
      end

      test "une saisie invalide donne :invalid, sans écriture" do
        result = update(name: "")

        assert_equal :invalid, result.code
        assert_equal [ :name ], result.errors.keys
        assert_equal 0, @transaction.calls
      end

      test "le nom d'une autre série donne :conflict, sans journal" do
        result = update(name: "C")

        assert_equal({ name: [ :taken ] }, result.errors)
        assert_equal :conflict, result.code
        assert_empty @audit_log.entries
      end
    end
  end
end

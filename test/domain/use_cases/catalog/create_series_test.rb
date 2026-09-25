require "test_helper"

module UseCases
  module Catalog
    class CreateSeriesTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)

      # Nom unique, comme l'index de la table ; le slug est dérivé du nom.
      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        attr_reader :created

        def initialize(names = [])
          @names = names
          @created = []
        end

        def create_series(series:)
          return Shared::Result.failure(:conflict, errors: { name: [ :taken ] }) if @names.include?(series.name)

          @created << Entities::Catalog::Series.new(id: 42, slug: series.name.parameterize, name: series.name)
          Shared::Result.success(@created.last)
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
        @taxonomy = FakeTaxonomy.new([ "C" ])
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def create(name: "D", actor: @team)
        CreateSeries.new(taxonomy: @taxonomy, audit_log: @audit_log, transaction: @transaction,
                         policy: Policies::Catalog::ManageTaxonomyPolicy.new, clock: Clock.new(NOW))
                    .call(actor:, dto: Dtos::Catalog::SeriesInput.new(name:))
      end

      test "crée la série, slug dérivé du nom, et journalise taxonomy.changed dans la transaction" do
        result = create(name: " D ")

        assert result.success?
        assert_equal [ 42, "d", "D" ], [ result.value.id, result.value.slug, result.value.name ]
        assert_equal [ { action: "taxonomy.changed", actor_id: 7, subject_type: "Series", subject_id: 42,
                         metadata: { change: "series.created", slug: "d" }, at: NOW } ], @audit_log.entries
        assert_equal 1, @transaction.calls
      end

      test "hors de l'équipe : :forbidden, avant même la saisie, et rien n'est écrit" do
        teacher = Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 1)

        assert_equal :forbidden, create(actor: teacher).code
        assert_equal :forbidden, create(actor: nil, name: "").code
        assert_empty @taxonomy.created
        assert_empty @audit_log.entries
      end

      test "une saisie invalide donne :invalid avec les erreurs du formulaire, sans écriture" do
        result = create(name: "a" * 11)

        assert_equal :invalid, result.code
        assert_equal [ :name ], result.errors.keys
        assert_equal 0, @transaction.calls
        assert_empty @taxonomy.created
      end

      test "un nom déjà pris donne :conflict sur le nom, sans journal" do
        result = create(name: "C")

        assert_equal :conflict, result.code
        assert_equal({ name: [ :taken ] }, result.errors)
        assert_empty @audit_log.entries
      end
    end
  end
end

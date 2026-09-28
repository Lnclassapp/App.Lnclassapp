require "test_helper"
require_relative "../../../support/domain/fake_classroom_plan"

module UseCases
  module Catalog
    class CreateLevelTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      Level = Entities::Catalog::Level

      # Comme le repository : slug dérivé du nom (-2 en cas de collision), nom et position uniques.
      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        attr_reader :levels

        def initialize(levels = [])
          @levels = levels
        end

        def create_level(level:)
          taken = %i[name position].find { |field| @levels.any? { it.public_send(field) == level.public_send(field) } }
          return Shared::Result.failure(:conflict, errors: { taken => [ :taken ] }) if taken

          slug = Entities::Catalog::Slug.unique(level.name, taken: @levels.to_set(&:slug))
          created = Level.new(id: @levels.size + 1, slug:, name: level.name, position: level.position, cycle: level.cycle)
          @levels << created
          Shared::Result.success(created)
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
        @taxonomy = FakeTaxonomy.new
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @plan = FakeClassroomPlan.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def create(actor: @team, name: "6ème", position: "1", cycle: "first")
        dto = Dtos::Catalog::LevelInput.new(name:, position:, cycle:)
        CreateLevel.new(taxonomy: @taxonomy, classroom_plan: @plan, audit_log: @audit_log, transaction: @transaction,
                        policy: Policies::Catalog::ManageTaxonomyPolicy.new, clock: Clock.new(NOW))
                   .call(actor:, dto:)
      end

      test "l'équipe crée un niveau ; son slug, dérivé du nom, est son code, et le journal le garde" do
        result = create

        assert result.success?
        assert_equal [ 1, "6eme", "6ème", 1, "first" ],
                     [ result.value.id, result.value.slug, result.value.name, result.value.position, result.value.cycle ]
        assert_equal({ action: "taxonomy.changed", actor_id: 7, at: NOW, subject_type: "Level", subject_id: 1,
                       metadata: { operation: "create", slug: "6eme" } }, @audit_log.records.first)
        assert_equal 1, @transaction.calls
      end

      test "D1 (owner, 2026-09-28): a level of the first cycle with a known code gets its barème defaults, journaled" do
        create(name: "4ème", cycle: "first")

        assert_equal [ 10, 4 ], %w[public private].map { @plan.plan.count(school_type: it, level_id: 1) }
        assert_equal [ [ "public", nil, 10, "auto" ], [ "private", nil, 4, "auto" ] ],
                     @audit_log.records.drop(1).map { it[:metadata].values_at(:school_type, :from, :to, :source) }
      end

      test "no reliable rule: another level of the first cycle, or a level of the second, stays undefined" do
        create(name: "Sixième bis", cycle: "first")
        create(name: "Tle", position: "7", cycle: "second")

        assert_empty @plan.saves
        assert_equal [ "taxonomy.changed" ], @audit_log.records.map { it[:action] }.uniq
      end

      test "hors équipe, rien n'est écrit, même avec une saisie invalide : la policy passe en premier" do
        teacher = Entities::Identity::Actor.new(user_id: 8, role: :teacher, school_id: 3)

        assert_equal :forbidden, create(actor: teacher).code
        assert_equal :forbidden, create(actor: nil, name: "").code
        assert_empty @taxonomy.levels
        assert_empty @audit_log.records
      end

      test "une saisie invalide est refusée avec les erreurs du formulaire" do
        result = create(name: "", cycle: "both")

        assert_equal :invalid, result.code
        assert_equal %i[name cycle], result.errors.keys
        assert_empty @taxonomy.levels
        assert_equal 0, @transaction.calls
      end

      test "une position négative, bien formée, est refusée par l'entité" do
        result = create(position: "-1")

        assert_equal :invalid, result.code
        assert_equal [ :position ], result.errors.keys
        assert_empty @taxonomy.levels
      end

      test "un nom ou une position déjà pris : conflit sur le champ, rien au journal" do
        create

        assert_equal({ name: [ :taken ] }, create(position: "2").errors)
        assert_equal({ position: [ :taken ] }, create(name: "5ème").errors)
        assert_equal :conflict, create(position: "2").code
        assert_equal 1, @taxonomy.levels.size
        assert_equal 1, @audit_log.records.count { it[:action] == "taxonomy.changed" }
        assert_equal 1, @plan.saves.size
      end
    end
  end
end

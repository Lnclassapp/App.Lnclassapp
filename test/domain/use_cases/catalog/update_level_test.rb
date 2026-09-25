require "test_helper"

module UseCases
  module Catalog
    class UpdateLevelTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      Level = Entities::Catalog::Level

      # Comme le repository : la mise à jour reprend nom, position et cycle, jamais le slug.
      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        attr_reader :levels

        def initialize(levels)
          @levels = levels
        end

        def find_level(slug:) = @levels.find { it.slug == slug }

        def update_level(level:)
          others = @levels.reject { it.id == level.id }
          taken = %i[name position].find { |field| others.any? { it.public_send(field) == level.public_send(field) } }
          return Shared::Result.failure(:conflict, errors: { taken => [ :taken ] }) if taken

          stored = @levels.find { it.id == level.id }
          updated = Level.new(id: stored.id, slug: stored.slug, name: level.name, position: level.position, cycle: level.cycle)
          @levels = others + [ updated ]
          Shared::Result.success(updated)
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
                                       Level.new(id: 2, slug: "5eme", name: "5ème", position: 2, cycle: "first") ])
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def update(slug: "6eme", actor: @team, name: "Sixième", position: "1", cycle: "first")
        dto = Dtos::Catalog::LevelInput.new(name:, position:, cycle:)
        UpdateLevel.new(taxonomy: @taxonomy, audit_log: @audit_log, transaction: @transaction,
                        policy: Policies::Catalog::ManageTaxonomyPolicy.new, clock: Clock.new(NOW))
                   .call(actor:, slug:, dto:)
      end

      test "renommer un niveau ne change pas son slug : la génération des classes et les imports le reconnaissent" do
        result = update(position: "3", cycle: "second")

        assert result.success?
        assert_equal [ 1, "6eme", "Sixième", 3, "second" ],
                     [ result.value.id, result.value.slug, result.value.name, result.value.position, result.value.cycle ]
        assert_equal "Sixième", @taxonomy.find_level(slug: "6eme").name
        assert_equal [ { action: "taxonomy.changed", actor_id: 7, at: NOW, subject_type: "Level", subject_id: 1,
                         metadata: { operation: "update", slug: "6eme" } } ], @audit_log.records
        assert_equal 1, @transaction.calls
      end

      test "hors équipe, rien ne change, même pour un niveau inconnu" do
        teacher = Entities::Identity::Actor.new(user_id: 8, role: :teacher, school_id: 3)

        assert_equal :forbidden, update(actor: teacher).code
        assert_equal :forbidden, update(actor: nil, slug: "inconnu").code
        assert_equal "6ème", @taxonomy.find_level(slug: "6eme").name
        assert_empty @audit_log.records
      end

      test "un niveau inconnu est introuvable" do
        assert_equal :not_found, update(slug: "inconnu").code
        assert_equal 0, @transaction.calls
      end

      test "une saisie invalide, ou une position négative, est refusée sans rien écrire" do
        invalid = update(name: "a" * 21)
        negative = update(position: "-1")

        assert_equal [ :invalid, [ :name ] ], [ invalid.code, invalid.errors.keys ]
        assert_equal [ :invalid, [ :position ] ], [ negative.code, negative.errors.keys ]
        assert_equal "6ème", @taxonomy.find_level(slug: "6eme").name
        assert_equal 0, @transaction.calls
      end

      test "un nom déjà pris par un autre niveau : conflit sur le nom, rien au journal" do
        result = update(name: "5ème")

        assert_equal [ :conflict, { name: [ :taken ] } ], [ result.code, result.errors ]
        assert_empty @audit_log.records
      end
    end
  end
end

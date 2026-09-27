require "test_helper"

module UseCases
  module School
    class UpdateDrenaTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      TEAM = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")

      # Comme la base : update n'écrit que le nom, le slug reste celui de la création.
      class FakeDrenas
        include Ports::School::DrenaRepositoryPort

        attr_reader :updated

        def initialize(drena, taken: [])
          @drena = drena
          @taken = taken
        end

        def find_by_public_id(public_id:)
          @drena if public_id == @drena.public_id
        end

        def update(drena:)
          return Shared::Result.failure(:conflict, errors: { name: [ :taken ] }) if @taken.include?(drena.name)

          @updated = drena
          Shared::Result.success(drena)
        end
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def record(**event) = (@events ||= []) << event
      end

      def update(name, public_id: "abj1abj1abj1ab", actor: TEAM, taken: [])
        drena = Entities::School::Drena.new(id: 12, public_id: "abj1abj1abj1ab", slug: "abidjan-1", name: "Abidjan 1")
        @drenas = FakeDrenas.new(drena, taken:)
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        UpdateDrena.new(drenas: @drenas, audit_log: @audit, transaction: @transaction,
                        policy: Policies::School::ManageSchoolPolicy.new, clock: Clock.new(NOW))
                   .call(actor:, public_id:, dto: Dtos::School::DrenaInput.new(name:))
      end

      test "renommer ne change pas le slug, et le changement est journalisé" do
        result = update(" Abidjan 1  Plateau ")

        assert result.success?
        assert_equal "Abidjan 1 Plateau", @drenas.updated.name
        assert_equal "abidjan-1", @drenas.updated.slug
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "school.changed", actor_id: 7, at: NOW, subject_type: "Drena", subject_id: 12,
                         metadata: { change: "drena.updated", name: "Abidjan 1 Plateau", previous_name: "Abidjan 1" } } ],
                     @audit.events
      end

      test "refuse un non-membre de l'équipe avant de chercher la DRENA" do
        result = update("Abidjan 1 Plateau", public_id: "inconnu", actor: Entities::Identity::Actor.new(user_id: 3, role: :teacher))

        assert_equal :forbidden, result.code
        assert_nil @drenas.updated
      end

      test "une DRENA inconnue est introuvable" do
        result = update("Abidjan 1 Plateau", public_id: "inconnu")

        assert_equal :not_found, result.code
        assert_equal 0, @transaction.calls
      end

      test "un nom trop long est invalide et rien n'est écrit" do
        result = update("a" * 81)

        assert_equal :invalid, result.code
        assert_equal [ :name ], result.errors.keys
        assert_nil @drenas.updated
      end

      test "un nom déjà pris est un conflit sur le nom, sans journal" do
        result = update("Abidjan 2", taken: [ "Abidjan 2" ])

        assert_equal :conflict, result.code
        assert_equal({ name: [ :taken ] }, result.errors)
        assert_nil @audit.events
      end
    end
  end
end

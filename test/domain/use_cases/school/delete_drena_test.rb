require "test_helper"

module UseCases
  module School
    class DeleteDrenaTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      TEAM = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")

      # Comme la base : une DRENA qui a des établissements ne se supprime pas (ADR-0036), aucune cascade.
      class FakeDrenas
        include Ports::School::DrenaRepositoryPort

        attr_reader :deleted

        def initialize(drena, with_schools:)
          @drena = drena
          @with_schools = with_schools
        end

        def find_by_public_id(public_id:)
          @drena if public_id == @drena.public_id
        end

        def delete(id:)
          return Shared::Result.failure(:conflict, errors: { base: [ :has_schools ] }) if @with_schools

          @deleted = id
          Shared::Result.success
        end
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def record(**event) = (@events ||= []) << event
      end

      def delete(public_id: "abj1abj1abj1ab", actor: TEAM, with_schools: false)
        @drena = Entities::School::Drena.new(id: 12, public_id: "abj1abj1abj1ab", slug: "drena-abidjan-1", name: "Abidjan 1")
        @drenas = FakeDrenas.new(@drena, with_schools:)
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        DeleteDrena.new(drenas: @drenas, audit_log: @audit, transaction: @transaction,
                        policy: Policies::School::ManageSchoolPolicy.new, clock: Clock.new(NOW))
                   .call(actor:, public_id:)
      end

      test "supprime une DRENA sans établissement, la renvoie et journalise la suppression" do
        result = delete

        assert result.success?
        assert_equal @drena, result.value
        assert_equal 12, @drenas.deleted
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "school.changed", actor_id: 7, at: NOW, subject_type: "Drena", subject_id: 12,
                         metadata: { change: "drena.deleted", name: "Abidjan 1" } } ], @audit.events
      end

      test "une DRENA qui a des établissements est refusée avec la raison, sans journal" do
        result = delete(with_schools: true)

        assert_equal :conflict, result.code
        assert_equal({ base: [ :has_schools ] }, result.errors)
        assert_nil @drenas.deleted
        assert_nil @audit.events
      end

      test "refuse un non-membre de l'équipe" do
        result = delete(actor: Entities::Identity::Actor.new(user_id: 4, role: :student))

        assert_equal :forbidden, result.code
        assert_nil @drenas.deleted
      end

      test "une DRENA inconnue est introuvable" do
        result = delete(public_id: "inconnu")

        assert_equal :not_found, result.code
        assert_equal 0, @transaction.calls
      end
    end
  end
end

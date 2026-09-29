require "test_helper"

module UseCases
  module School
    class CreateDrenaTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      TEAM = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")

      # Comme la base : le slug est tiré du nom à la création, un nom déjà pris est un conflit.
      class FakeDrenas
        include Ports::School::DrenaRepositoryPort

        attr_reader :created

        def initialize(taken: [])
          @taken = taken
          @created = []
        end

        def create(drena:)
          return Shared::Result.failure(:conflict, errors: { name: [ :taken ] }) if @taken.include?(drena.name)

          drena.id = 12
          drena.public_id = "pub12345678901"
          drena.slug = Entities::School::Drena.slug_for(drena.name)
          @created << drena
          Shared::Result.success(drena)
        end
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def record(**event) = (@events ||= []) << event
      end

      def create(name, actor: TEAM, taken: [])
        @drenas = FakeDrenas.new(taken:)
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        CreateDrena.new(drenas: @drenas, audit_log: @audit, transaction: @transaction,
                        policy: Policies::School::ManageSchoolPolicy.new, clock: Clock.new(NOW))
                   .call(actor:, dto: Dtos::School::DrenaInput.new(name:))
      end

      test "l'équipe crée une DRENA : slug tiré du nom, dans une transaction, journalisée" do
        result = create("  Abidjan   1 ")

        assert result.success?
        assert_equal "Abidjan 1", result.value.name
        assert_equal "drena-abidjan-1", result.value.slug
        assert_equal [ result.value ], @drenas.created
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "school.changed", actor_id: 7, at: NOW, subject_type: "Drena", subject_id: 12,
                         metadata: { change: "drena.created", name: "Abidjan 1" } } ], @audit.events
      end

      test "refuse tout autre rôle et le visiteur, sans rien écrire" do
        [ nil, Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 1),
          Entities::Identity::Actor.new(user_id: 4, role: :student), Entities::Identity::Actor.new(user_id: 5, role: :school_admin) ].each do |actor|
          result = create("Abidjan 1", actor:)

          assert_equal :forbidden, result.code
          assert_empty @drenas.created
          assert_nil @audit.events
        end
      end

      test "un nom vide est invalide et rien n'est écrit" do
        result = create(" ")

        assert_equal :invalid, result.code
        assert_equal [ :name ], result.errors.keys
        assert_empty @drenas.created
        assert_equal 0, @transaction.calls
      end

      test "un nom déjà pris est un conflit sur le nom, sans journal" do
        result = create("Abidjan 1", taken: [ "Abidjan 1" ])

        assert_equal :conflict, result.code
        assert_equal({ name: [ :taken ] }, result.errors)
        assert_nil @audit.events
      end
    end
  end
end

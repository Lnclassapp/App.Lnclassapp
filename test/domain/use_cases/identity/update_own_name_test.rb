require "test_helper"

# PR-03, ADR-0055: a person renames their own account, within the sign-up limits, and the change is audited.
module UseCases
  module Identity
    class UpdateOwnNameTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 27, 12)
      Clock = Data.define(:now)

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        attr_reader :updates

        def initialize = @updates = []

        def update_name(**attributes)
          @updates << attributes
          true
        end
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :entries

        def initialize = @entries = []
        def record(**entry) = @entries << entry
      end

      setup do
        @user = Entities::Identity::User.new(id: 3, first_name: "Aya", last_name: "Koné", role: "student")
        @users = FakeUsers.new
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
      end

      def rename(last_name:, first_name:, actor: Entities::Identity::Actor.new(user_id: 3, role: :student))
        UpdateOwnName.new(users: @users, audit_log: @audit, transaction: @transaction,
                          policy: Policies::Identity::UpdateSelfPolicy.new, clock: Clock.new(NOW))
                     .call(actor:, user: @user, dto: Dtos::Identity::PersonNameInput.new(last_name:, first_name:), ip: "1.2.3.4")
      end

      test "the new name is written and audited with the old and the new name, in one transaction" do
        result = rename(last_name: " Koné ", first_name: "Aya  Marie")

        assert result.success?
        assert_equal [ { user_id: 3, first_name: "Aya Marie", last_name: "Koné" } ], @users.updates
        assert_equal [ { action: "profile.name_changed", actor_id: 3, at: NOW, subject_type: "User", subject_id: 3,
                         metadata: { previous: { first_name: "Aya", last_name: "Koné" },
                                     current: { first_name: "Aya Marie", last_name: "Koné" } }, ip: "1.2.3.4" } ], @audit.entries
        assert_equal 1, @transaction.calls
      end

      test "another account is refused before anything is checked" do
        result = rename(last_name: "", first_name: "", actor: Entities::Identity::Actor.new(user_id: 4, role: :teacher))

        assert_equal :forbidden, result.code
        assert_empty @users.updates
      end

      test "an empty, blank or too long name is refused with its errors, and nothing is written" do
        [ [ "", "Aya" ], [ "   ", "Aya" ], [ "a" * 51, "Aya" ], [ "Koné", "b" * 81 ], [ "Koné", "Aya 2" ] ].each do |last_name, first_name|
          result = rename(last_name:, first_name:)

          assert_equal :invalid, result.code, [ last_name, first_name ].inspect
          assert_not_empty result.errors
        end
        assert_empty @users.updates
        assert_empty @audit.entries
      end

      test "the same name succeeds without writing nor auditing anything" do
        assert rename(last_name: "Koné", first_name: " Aya ").success?
        assert_empty @users.updates
        assert_empty @audit.entries
      end
    end
  end
end

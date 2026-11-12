require "test_helper"

# CA-07, CA-08: the owner is an assignable member (admin or field), or nobody; the change is audited.
module UseCases
  module Crm
    class AssignOwnerTest < ActiveSupport::TestCase
      Member = Data.define(:user_id)

      class FakeAccounts
        include Ports::Crm::AccountRepositoryPort

        attr_reader :saved

        def initialize(account = nil) = @account = account
        def find_by_school_id(school_id:) = @account
        def save(account:) = Shared::Result.success(@saved = account)
      end

      class ConflictAccounts < FakeAccounts
        def save(account:) = Shared::Result.failure(:conflict, errors: { base: [ :write_failed ] })
      end

      class FakeAudit
        attr_reader :entries

        def initialize = @entries = []
        def record(**entry) = @entries << entry
      end

      class FakeTransaction
        def call(&) = yield
      end

      class FakeAssignable
        def call = [ Member.new(user_id: 7), Member.new(user_id: 8) ]
      end

      NOW = Time.utc(2026, 11, 6, 9)
      Clock = Struct.new(:now).new(NOW)

      def actor(team_role = "field") = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role:)

      def use_case(account = nil)
        AssignOwner.new(accounts: (@accounts = FakeAccounts.new(account)), audit_log: (@audit = FakeAudit.new),
                        transaction: FakeTransaction.new, policy: Policies::Crm::ManageCrmPolicy.new,
                        assignable: FakeAssignable.new, clock: Clock)
      end

      test "R2: a refused first write is returned as a conflict and nothing is audited" do
        use_case = AssignOwner.new(accounts: ConflictAccounts.new, audit_log: (audit = FakeAudit.new),
                              transaction: FakeTransaction.new, policy: Policies::Crm::ManageCrmPolicy.new, assignable: FakeAssignable.new, clock: Clock)

        result = use_case.call(actor: actor, school_id: 31, owner_id: 7)

        assert_equal :conflict, result.code
        assert_empty audit.entries
      end

      test "CA-07: naming an owner creates the account, keeps the prospect stage and is audited" do
        result = use_case.call(actor: actor, school_id: 31, owner_id: 7)

        assert result.success?
        assert_equal 7, @accounts.saved.owner_id
        assert_equal "prospect", @accounts.saved.stage
        entry = @audit.entries.sole
        assert_equal "crm.owner_changed", entry[:action]
        assert_equal({ from: nil, to: 7 }, entry[:metadata])
      end

      test "CA-08: a member who is not assignable is refused and the owner does not change" do
        current = Entities::Crm::Account.blank(31).with(owner_id: 8)
        result = use_case(current).call(actor: actor, school_id: 31, owner_id: 99)

        assert_equal :invalid, result.code
        assert_equal [ :invalid ], result.errors[:owner_id]
        assert_nil @accounts.saved
        assert_empty @audit.entries
      end

      test "no owner at all is allowed and audited" do
        current = Entities::Crm::Account.blank(31).with(owner_id: 8)
        use_case(current).call(actor: actor, school_id: 31, owner_id: nil)

        assert_nil @accounts.saved.owner_id
        assert_equal({ from: 8, to: nil }, @audit.entries.sole[:metadata])
      end

      test "the stage is kept when the owner changes" do
        current = Entities::Crm::Account.blank(31).with(stage: "lost", lost_reason: "price", stage_changed_at: NOW - 60)
        use_case(current).call(actor: actor, school_id: 31, owner_id: 8)

        assert_equal "lost", @accounts.saved.stage
        assert_equal "price", @accounts.saved.lost_reason
        assert_equal NOW - 60, @accounts.saved.stage_changed_at
      end

      test "the same owner again writes nothing" do
        current = Entities::Crm::Account.blank(31).with(owner_id: 8)
        assert use_case(current).call(actor: actor, school_id: 31, owner_id: 8).success?
        assert_nil @accounts.saved
      end

      test "a content member is forbidden" do
        assert_equal :forbidden, use_case.call(actor: actor("content"), school_id: 31, owner_id: 7).code
      end
    end
  end
end

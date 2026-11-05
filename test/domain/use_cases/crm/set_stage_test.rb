require "test_helper"

# CA-06, CA-07: a typed stage is one of the four judgments; « lost » needs a reason; the change is written to the audit log.
module UseCases
  module Crm
    class SetStageTest < ActiveSupport::TestCase
      class FakeAccounts
        include Ports::Crm::AccountRepositoryPort

        attr_reader :saved

        def initialize(account = nil) = @account = account
        def find_by_school_id(school_id:) = @account
        def save(account:) = Shared::Result.success(@saved = account)
      end

      class FakeAudit
        attr_reader :entries

        def initialize = @entries = []
        def record(**entry) = @entries << entry
      end

      class FakeTransaction
        def call(&) = yield
      end

      NOW = Time.utc(2026, 11, 6, 9)
      Clock = Struct.new(:now).new(NOW)

      def actor(team_role = "field") = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role:)

      def use_case(account = nil)
        SetStage.new(accounts: (@accounts = FakeAccounts.new(account)), audit_log: (@audit = FakeAudit.new),
                     transaction: FakeTransaction.new, policy: Policies::Crm::ManageCrmPolicy.new, clock: Clock)
      end

      test "CA-07: a first stage creates the account and is audited with from and to" do
        result = use_case.call(actor: actor, school_id: 31, stage: "demo_done", lost_reason: nil)

        assert result.success?
        assert_equal "demo_done", @accounts.saved.stage
        assert_equal NOW, @accounts.saved.stage_changed_at
        entry = @audit.entries.sole
        assert_equal "crm.stage_changed", entry[:action]
        assert_equal 7, entry[:actor_id]
        assert_equal({ from: "prospect", to: "demo_done", lost_reason: nil }, entry[:metadata])
      end

      test "CA-06: lost without a reason is invalid and nothing is written" do
        result = use_case.call(actor: actor, school_id: 31, stage: "lost", lost_reason: "")

        assert_equal :invalid, result.code
        assert_equal [ :blank ], result.errors[:lost_reason]
        assert_nil @accounts.saved
        assert_empty @audit.entries
      end

      test "an unknown reason is invalid" do
        assert_equal [ :inclusion ], use_case.call(actor: actor, school_id: 31, stage: "lost", lost_reason: "x").errors[:lost_reason]
      end

      test "lost with a reason keeps it, any other stage drops it" do
        use_case.call(actor: actor, school_id: 31, stage: "lost", lost_reason: "price")
        assert_equal "price", @accounts.saved.lost_reason

        lost = Entities::Crm::Account.blank(31).with(stage: "lost", lost_reason: "price")
        use_case(lost).call(actor: actor, school_id: 31, stage: "subscribed", lost_reason: "price")
        assert_nil @accounts.saved.lost_reason
        assert_equal({ from: "lost", to: "subscribed", lost_reason: nil }, @audit.entries.sole[:metadata])
      end

      test "registered and active are facts of usage: they cannot be typed" do
        %w[registered active nope].each do |stage|
          result = use_case.call(actor: actor, school_id: 31, stage:, lost_reason: nil)
          assert_equal :invalid, result.code
          assert_equal [ :inclusion ], result.errors[:stage]
        end
        assert_nil @accounts.saved
      end

      test "the same stage again writes nothing" do
        current = Entities::Crm::Account.blank(31).with(stage: "demo_done", stage_changed_at: NOW - 3600)
        result = use_case(current).call(actor: actor, school_id: 31, stage: "demo_done", lost_reason: nil)

        assert result.success?
        assert_nil @accounts.saved
        assert_empty @audit.entries
      end

      test "the owner is kept when the stage changes" do
        current = Entities::Crm::Account.blank(31).with(owner_id: 9)
        use_case(current).call(actor: actor, school_id: 31, stage: "subscribed", lost_reason: nil)

        assert_equal 9, @accounts.saved.owner_id
      end

      test "a content member is forbidden" do
        assert_equal :forbidden, use_case.call(actor: actor("content"), school_id: 31, stage: "demo_done", lost_reason: nil).code
        assert_nil @accounts.saved
      end
    end
  end
end

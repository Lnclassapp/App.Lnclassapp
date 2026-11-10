require "test_helper"

# CA-13: « Faite » takes a follow-up out of the open ones; completing one already done changes nothing.
module UseCases
  module Crm
    class CompleteFollowUpTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 5, 9)
      Clock = Data.define(:now)

      class FakeFollowUps
        include Ports::Crm::FollowUpRepositoryPort

        attr_reader :completions

        def initialize(*follow_ups)
          @follow_ups = follow_ups
          @completions = []
        end

        def find_by_public_id(public_id:) = @follow_ups.find { it.public_id == public_id }

        def complete(public_id:, by_id:, at:)
          @completions << { public_id:, by_id:, at: }
          Shared::Result.success(find_by_public_id(public_id:).with(status: "done", done_at: at, done_by_id: by_id))
        end
      end

      def follow_up(**overrides)
        Entities::Crm::FollowUp.new(public_id: "fu-1", school_id: 31, assignee_id: 7, due_on: Date.new(2026, 11, 6),
                                    reason: "Rappeler", status: "open", done_at: nil, done_by_id: nil, created_by_id: 7,
                                    interaction_id: nil, **overrides)
      end

      def use_case(*follow_ups) = CompleteFollowUp.new(follow_ups: (@repo = FakeFollowUps.new(*follow_ups)),
                                                       policy: Policies::Crm::ManageCrmPolicy.new, clock: Clock.new(NOW))

      setup { @actor = Entities::Identity::Actor.new(user_id: 8, role: :team, team_role: "field") }

      test "marks an open follow-up done, by the actor, now" do
        result = use_case(follow_up).call(actor: @actor, public_id: "fu-1")

        assert result.success?
        assert_equal [ { public_id: "fu-1", by_id: 8, at: NOW } ], @repo.completions
        assert_equal "done", result.value.status
      end

      test "CA-13: a follow-up already done is returned as is, without a second write" do
        done = follow_up(status: "done", done_at: NOW - 3600, done_by_id: 7)

        result = use_case(done).call(actor: @actor, public_id: "fu-1")

        assert result.success?
        assert_equal done, result.value
        assert_empty @repo.completions
      end

      test "an unknown follow-up is not found" do
        assert_equal :not_found, use_case.call(actor: @actor, public_id: "nope").code
      end

      test "a content member is forbidden" do
        content = Entities::Identity::Actor.new(user_id: 9, role: :team, team_role: "content")

        assert_equal :forbidden, use_case(follow_up).call(actor: content, public_id: "fu-1").code
        assert_empty @repo.completions
      end
    end
  end
end

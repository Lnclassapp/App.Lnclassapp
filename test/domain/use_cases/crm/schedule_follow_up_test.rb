require "test_helper"

# CA-13 (ADR-XXXX contexte crm): a follow-up is created open, for a school, confiée à un membre assignable, avec un motif.
module UseCases
  module Crm
    class ScheduleFollowUpTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 5, 9)
      Clock = Data.define(:now)
      Member = Data.define(:user_id)

      class FakeFollowUps
        include Ports::Crm::FollowUpRepositoryPort

        attr_reader :created

        def create(follow_up:)
          @created = follow_up
          Shared::Result.success(follow_up.with(public_id: "fu-new"))
        end
      end

      class FakeAssignable
        def call = [ Member.new(user_id: 7), Member.new(user_id: 8) ]
      end

      setup do
        @follow_ups = FakeFollowUps.new
        @use_case = ScheduleFollowUp.new(follow_ups: @follow_ups, policy: Policies::Crm::ManageCrmPolicy.new,
                                         assignable: FakeAssignable.new, clock: Clock.new(NOW))
        @actor = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field")
      end

      def schedule(actor: @actor, **overrides)
        @use_case.call(actor:, school_id: 31, assignee_id: 7, due_on: Date.new(2026, 11, 6), reason: "Rappeler la direction", **overrides)
      end

      test "creates an open follow-up for tomorrow, signed by the actor" do
        result = schedule

        assert result.success?
        assert_equal "fu-new", result.value.public_id
        created = @follow_ups.created
        assert_equal [ 31, 7, Date.new(2026, 11, 6), "Rappeler la direction", "open", 7 ],
                     [ created.school_id, created.assignee_id, created.due_on, created.reason, created.status, created.created_by_id ]
        assert_nil created.done_at
      end

      test "an admin may hand it to another member" do
        assert schedule(assignee_id: 8).success?
        assert_equal 8, @follow_ups.created.assignee_id
      end

      test "the reason is squished" do
        schedule(reason: "  Rappeler   la direction \n")

        assert_equal "Rappeler la direction", @follow_ups.created.reason
      end

      test "a blank reason is refused" do
        result = schedule(reason: "   ")

        assert_equal :invalid, result.code
        assert_equal [ :blank ], result.errors[:reason]
        assert_nil @follow_ups.created
      end

      test "a reason over 200 characters is refused" do
        result = schedule(reason: "x" * 201)

        assert_equal [ :too_long ], result.errors[:reason]
        assert schedule(reason: "x" * 200).success?
      end

      test "a missing date is refused" do
        result = schedule(due_on: nil)

        assert_equal [ :blank ], result.errors[:due_on]
        assert_nil @follow_ups.created
      end

      test "an assignee who cannot take follow-ups is refused" do
        result = schedule(assignee_id: 99)

        assert_equal :invalid, result.code
        assert_equal [ :invalid ], result.errors[:assignee_id]
        assert_nil @follow_ups.created
      end

      test "a content member is forbidden" do
        result = schedule(actor: Entities::Identity::Actor.new(user_id: 9, role: :team, team_role: "content"))

        assert_equal :forbidden, result.code
        assert_nil @follow_ups.created
      end
    end
  end
end

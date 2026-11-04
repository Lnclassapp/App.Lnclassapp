require "test_helper"

# ADR-XXXX (contexte crm) §4: a follow-up is created open, completed once (a second completion changes nothing),
# reassigned, and read back as an entity. Shared by the journal (Lot C) and the follow-ups (Lot D).
module Repositories
  module Crm
    class FollowUpRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = FollowUpRepository.new
        @school = create_school
        @author = create_team_member(team_role: "field")
        @at = Time.utc(2026, 11, 5, 9)
      end

      def follow_up(**overrides)
        Entities::Crm::FollowUp.new(public_id: nil, school_id: @school.id, assignee_id: @author.id, due_on: Date.new(2026, 11, 6),
                                    reason: "Rappeler la direction", status: "open", done_at: nil, done_by_id: nil,
                                    created_by_id: @author.id, interaction_id: nil, **overrides)
      end

      test "create writes an open follow-up and returns it with its public id" do
        result = @repository.create(follow_up: follow_up)

        assert result.success?
        created = result.value
        assert_equal 14, created.public_id.length
        assert_equal [ "open", @school.id, @author.id, Date.new(2026, 11, 6), "Rappeler la direction" ],
                     [ created.status, created.school_id, created.assignee_id, created.due_on, created.reason ]
        assert created.open?
      end

      test "find_by_public_id returns the entity, or nil" do
        created = @repository.create(follow_up: follow_up).value

        assert_equal created, @repository.find_by_public_id(public_id: created.public_id)
        assert_nil @repository.find_by_public_id(public_id: "unknown-public")
      end

      test "complete marks it done, with who and when" do
        created = @repository.create(follow_up: follow_up).value

        done = @repository.complete(public_id: created.public_id, by_id: @author.id, at: @at).value

        assert_equal [ "done", @at, @author.id ], [ done.status, done.done_at, done.done_by_id ]
        assert_not done.open?
      end

      test "completing a follow-up already done changes nothing and is not an error" do
        created = @repository.create(follow_up: follow_up).value
        @repository.complete(public_id: created.public_id, by_id: @author.id, at: @at)
        other = create_team_member

        again = @repository.complete(public_id: created.public_id, by_id: other.id, at: @at + 1.hour)

        assert again.success?
        assert_equal [ @author.id, @at ], [ again.value.done_by_id, again.value.done_at ]
      end

      test "completing an unknown follow-up is :not_found" do
        assert_equal :not_found, @repository.complete(public_id: "unknown-public", by_id: @author.id, at: @at).code
      end

      test "reassign changes the assignee of an open follow-up" do
        created = @repository.create(follow_up: follow_up).value
        other = create_team_member(team_role: "admin")

        reassigned = @repository.reassign(public_id: created.public_id, assignee_id: other.id)

        assert_equal other.id, reassigned.value.assignee_id
      end

      test "reassigning an unknown follow-up is :not_found" do
        assert_equal :not_found, @repository.reassign(public_id: "unknown-public", assignee_id: @author.id).code
      end

      test "a due date and a reason are required by the table" do
        assert_raises(ActiveRecord::NotNullViolation) { @repository.create(follow_up: follow_up(due_on: nil)) }
        assert_raises(ActiveRecord::StatementInvalid) { @repository.create(follow_up: follow_up(reason: "x" * 201)) }
      end

      test "a done follow-up must carry its completion, an open one must not" do
        assert_raises(ActiveRecord::StatementInvalid) { @repository.create(follow_up: follow_up(status: "done")) }
        assert_raises(ActiveRecord::StatementInvalid) { @repository.create(follow_up: follow_up(done_at: @at)) }
      end
    end
  end
end

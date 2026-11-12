require "test_helper"

# CA-14: an admin reassigns any open follow-up, a field member only those of the schools he owns.
module UseCases
  module Crm
    class ReassignFollowUpTest < ActiveSupport::TestCase
      Member = Data.define(:user_id)

      class FakeFollowUps
        include Ports::Crm::FollowUpRepositoryPort

        attr_reader :reassigned

        def initialize(*follow_ups)
          @follow_ups = follow_ups
        end

        def find_by_public_id(public_id:) = @follow_ups.find { it.public_id == public_id }

        def reassign(public_id:, assignee_id:)
          @reassigned = { public_id:, assignee_id: }
          Shared::Result.success(find_by_public_id(public_id:).with(assignee_id:))
        end
      end

      # Le responsable de l'école, lu par une requête (le compte d'une école jamais suivie n'existe pas : nil).
      class FakeOwners
        def initialize(owner_id) = @owner_id = owner_id

        def owner_id(school_id:) = @owner_id
      end

      class FakeAssignable
        def call = [ Member.new(user_id: 7), Member.new(user_id: 8), Member.new(user_id: 9) ]
      end

      def follow_up(**overrides)
        Entities::Crm::FollowUp.new(public_id: "fu-1", school_id: 31, assignee_id: 55, due_on: Date.new(2026, 11, 6),
                                    reason: "Rappeler", status: "open", done_at: nil, done_by_id: nil, created_by_id: 7,
                                    interaction_id: nil, **overrides)
      end

      def use_case(owner_id: nil, follow_ups: [ follow_up ])
        ReassignFollowUp.new(follow_ups: (@repo = FakeFollowUps.new(*follow_ups)), owners: FakeOwners.new(owner_id),
                             policy: Policies::Crm::ManageCrmPolicy.new, assignable: FakeAssignable.new)
      end

      def actor(user_id, team_role) = Entities::Identity::Actor.new(user_id:, role: :team, team_role:)

      test "CA-14: an admin reassigns the follow-up of an unavailable recipient" do
        result = use_case.call(actor: actor(1, "admin"), public_id: "fu-1", assignee_id: 8)

        assert result.success?
        assert_equal({ public_id: "fu-1", assignee_id: 8 }, @repo.reassigned)
        assert_equal 8, result.value.assignee_id
      end

      test "CA-14: the field member who owns the school reassigns it" do
        assert use_case(owner_id: 7).call(actor: actor(7, "field"), public_id: "fu-1", assignee_id: 8).success?
      end

      test "CA-14: a field member who does not own the school cannot" do
        result = use_case(owner_id: 9).call(actor: actor(7, "field"), public_id: "fu-1", assignee_id: 8)

        assert_equal :forbidden, result.code
        assert_nil @repo.reassigned
      end

      test "a school without owner is reassigned by an admin only" do
        assert_equal :forbidden, use_case.call(actor: actor(7, "field"), public_id: "fu-1", assignee_id: 8).code
      end

      test "the new recipient must be an assignable member" do
        result = use_case.call(actor: actor(1, "admin"), public_id: "fu-1", assignee_id: 99)

        assert_equal :invalid, result.code
        assert_equal [ :invalid ], result.errors[:assignee_id]
        assert_nil @repo.reassigned
      end

      test "a follow-up already done is not found, an unknown one too" do
        done = follow_up(status: "done", done_at: Time.utc(2026, 11, 5), done_by_id: 7)

        assert_equal :not_found, use_case(follow_ups: [ done ]).call(actor: actor(1, "admin"), public_id: "fu-1", assignee_id: 8).code
        assert_equal :not_found, use_case.call(actor: actor(1, "admin"), public_id: "nope", assignee_id: 8).code
      end

      test "a content member is forbidden" do
        assert_equal :forbidden, use_case.call(actor: actor(1, "content"), public_id: "fu-1", assignee_id: 8).code
      end

      test "allowed? is the rule the screens share" do
        assert ReassignFollowUp.allowed?(actor: actor(1, "admin"), owner_id: nil)
        assert ReassignFollowUp.allowed?(actor: actor(7, "field"), owner_id: 7)
        assert_not ReassignFollowUp.allowed?(actor: actor(7, "field"), owner_id: 9)
        assert_not ReassignFollowUp.allowed?(actor: actor(7, "field"), owner_id: nil)
      end
    end
  end
end

require "test_helper"

module Repositories
  module Communication
    # ADR-0036 (amendement), notifications-push: anonymizing a student leaves no row in push_subscriptions, push_preferences
    # or push_deliveries; another student's rows stay.
    class PushDataEraserTest < ActiveSupport::TestCase
      test "erases the three push tables of the user and only theirs" do
        student = create_student
        other = create_student
        [ student, other ].each do |user|
          create_push_subscription(user:)
          create_push_preference(user:)
          create_push_delivery(user:)
        end

        assert PushDataEraser.new.erase_for(user_id: student.id)

        [ Orm::Communication::PushSubscription, Orm::Communication::PushPreference, Orm::Communication::PushDelivery ].each do |model|
          assert_equal 0, model.where(user_id: student.id).count
          assert_equal 1, model.where(user_id: other.id).count
        end
      end

      test "erases the approval recipients of the user, keeps the approval and the other recipients" do
        student = create_student
        other = create_student
        approval = create_push_approval(motive: "unfinished", recipients: [ [ student.id, "unfinished:a" ], [ other.id, "unfinished:b" ] ])

        PushDataEraser.new.erase_for(user_id: student.id)

        assert_equal [ other.id ], approval.recipients.pluck(:user_id)
        assert Orm::Communication::PushApproval.exists?(approval.id)
      end
    end
  end
end

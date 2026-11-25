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
    end
  end
end

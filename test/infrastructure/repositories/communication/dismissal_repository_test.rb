require "test_helper"

# ADR-0045 §4 and ADR-0078 §4.1: a dismissal is a row (message, account), unique, so that a hidden message stays hidden on
# every device of the student; restoring it removes the row.
module Repositories
  module Communication
    class DismissalRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = DismissalRepository.new
        @message = create_message(author: create_team_member(second_factor: false), audience: "all")
        @awa = create_student
      end

      def dismissals = Orm::MessageDismissal.where(message: @message).pluck(:user_id, :dismissed_at)

      test "dismiss writes the dismissal of the account at the given time" do
        at = Time.utc(2026, 10, 4, 10)

        assert @repository.dismiss(message_id: @message.id, user_id: @awa.id, at:)
        assert_equal [ [ @awa.id, at ] ], dismissals
      end

      test "a second dismissal keeps the first one, without error" do
        first = Time.utc(2026, 10, 4, 10)
        @repository.dismiss(message_id: @message.id, user_id: @awa.id, at: first)

        assert @repository.dismiss(message_id: @message.id, user_id: @awa.id, at: first + 1.hour)
        assert_equal [ [ @awa.id, first ] ], dismissals
      end

      test "restore removes the dismissal of this account alone, and says whether there was one" do
        other = create_student
        dismiss_message(message: @message, user: @awa)
        dismiss_message(message: @message, user: other)

        assert @repository.restore(message_id: @message.id, user_id: @awa.id)
        assert_not @repository.restore(message_id: @message.id, user_id: @awa.id)
        assert_equal [ other.id ], dismissals.map(&:first)
      end
    end
  end
end

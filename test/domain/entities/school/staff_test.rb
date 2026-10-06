require "test_helper"

# ADR-0077 : une direction est « nouvel arrivant » 7 jours, et un compte archivé est supprimé 30 jours après.
module Entities
  module School
    class StaffTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 4, 12)

      def staff(joined_at: NOW, archived_at: nil, joined_via: "code")
        Staff.new(user_id: 1, user_public_id: "u", school_id: 2, joined_via:, joined_at:, archived_at:, archived_by_id: nil)
      end

      test "the cap, the newcomer window and the retention are those of the decision" do
        assert_equal [ 3, 7, 30 ], [ Staff::CODE_CAP, Staff::NEWCOMER_DAYS, Staff::RETENTION_DAYS ]
      end

      test "a direction is a newcomer for 7 days, then it is not" do
        assert staff(joined_at: NOW - (7 * 86_400) + 1).newcomer?(NOW)
        assert_not staff(joined_at: NOW - (7 * 86_400)).newcomer?(NOW)
      end

      test "an archived account is deleted 30 days after its archiving" do
        assert_nil staff.deletion_due_at
        assert_not staff.archived?
        archived = staff(archived_at: NOW)

        assert archived.archived?
        assert_equal NOW + (30 * 86_400), archived.deletion_due_at
      end

      test "by_code? tells the code arrival from the invitation" do
        assert staff.by_code?
        assert_not staff(joined_via: "invitation").by_code?
      end
    end
  end
end

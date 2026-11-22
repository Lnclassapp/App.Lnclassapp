require "test_helper"

module Entities
  module Classroom
    # ADR attribution-des-inscriptions-eleves §4.2 : the table, row by row.
    class SignupSourceTest < ActiveSupport::TestCase
      test "link with a resolved inviter is a student invite, whatever the qr tag" do
        assert_equal "student_invite", SignupSource.resolve(via: "link", qr: false, inviter_id: 7)
        assert_equal "student_invite", SignupSource.resolve(via: "link", qr: true, inviter_id: 7)
      end

      test "link without inviter is qr when tagged, teacher link otherwise" do
        assert_equal "qr", SignupSource.resolve(via: "link", qr: true, inviter_id: nil)
        assert_equal "teacher_link", SignupSource.resolve(via: "link", qr: false, inviter_id: nil)
      end

      test "the code way is code, even with an inviter or a qr tag" do
        assert_equal "code", SignupSource.resolve(via: "code", qr: true, inviter_id: 7)
      end

      test "a chosen classroom is cold, even with an inviter or a qr tag" do
        assert_equal "cold", SignupSource.resolve(via: "standard", qr: true, inviter_id: 7)
        assert_equal "cold", SignupSource.resolve(via: nil, qr: false, inviter_id: nil)
      end

      test "the five sources and the qr tag" do
        assert_equal %w[qr student_invite teacher_link code cold], SignupSource::ALL
        assert_equal "qr", SignupSource::QR_TAG
      end
    end
  end
end

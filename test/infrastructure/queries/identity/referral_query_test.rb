require "test_helper"

module Queries
  module Identity
    # CP-01, CP-06 (ADR-0063, UDR-0050): what the « Inviter un collègue » block shows of the teacher signed in.
    # IE-06 (ADR-0083 §4.1): the link is /i/<token>; the row no longer carries the school's code.
    class ReferralQueryTest < ActiveSupport::TestCase
      test "IE-06: the primary school, the teacher's token and the number of referees, without the school's code" do
        school = create_school(name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
        teacher = create_teacher(school:)
        2.times { create_referral(referrer: teacher) }
        create_referral # someone else's

        row = ReferralQuery.new.call(teacher_id: teacher.id)

        assert_equal ReferralQuery::Row.new(school_name: "Lycée Classique d'Abidjan",
                                            referral_token: Orm::TeacherProfile.find_by!(user: teacher).referral_token, referred_count: 2),
                     row
        assert_not_includes ReferralQuery::Row.members, :school_code
      end

      test "a teacher without primary school, or without profile, has nothing to share" do
        assert_nil ReferralQuery.new.call(teacher_id: create_teacher(school: nil).id)
        assert_nil ReferralQuery.new.call(teacher_id: create_user(role: "teacher").id)
      end

      test "two queries, whatever the number of referees" do
        teacher = create_teacher
        3.times { create_referral(referrer: teacher) }
        count = 0
        ActiveSupport::Notifications.subscribed(->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }, "sql.active_record") do
          ReferralQuery.new.call(teacher_id: teacher.id)
        end

        assert_equal 2, count
      end
    end
  end
end

require "test_helper"

module Queries
  module Identity
    # CP-01, CP-06 (ADR-0063, UDR-0050): what the « Inviter un collègue » block shows of the teacher signed in.
    # IE-06 (ADR-0083 §4.1): the links are /i/<token>; the row carries no school's code.
    # ME-26, ME-27 (ADR-0094 §11, MET-8): two links, the one of the current school and the sponsor link without school.
    class ReferralQueryTest < ActiveSupport::TestCase
      test "ME-26: the current school, its link, the sponsor link and the number of referees, without the school's code" do
        school = create_school(name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
        teacher = create_teacher(school:)
        2.times { create_referral(referrer: teacher) }
        create_referral # someone else's

        row = ReferralQuery.new.call(teacher_id: teacher.id, school_id: school.id)

        assert_equal ReferralQuery::Row.new(school_name: "Lycée Classique d'Abidjan",
                                            school_token: Orm::TeacherSchool.find_by!(teacher:).invite_token,
                                            referral_token: Orm::TeacherProfile.find_by!(user: teacher).referral_token, referred_count: 2),
                     row
        assert_not_includes ReferralQuery::Row.members, :school_code
      end

      test "ME-26: in his second school, the link is that school's" do
        teacher = create_teacher
        second = create_school(name: "Collège Saint-Michel")
        token = add_teacher_school(teacher, second).invite_token

        assert_equal [ "Collège Saint-Michel", token ], ReferralQuery.new.call(teacher_id: teacher.id, school_id: second.id)
                                                                         .then { [ it.school_name, it.school_token ] }
      end

      test "a school he does not belong to, a teacher without school, or without profile, has nothing to share" do
        assert_nil ReferralQuery.new.call(teacher_id: create_teacher.id, school_id: create_school.id)
        assert_nil ReferralQuery.new.call(teacher_id: create_teacher(school: nil).id, school_id: nil)
        user = create_user(role: "teacher")
        school = create_school
        Orm::TeacherSchool.create!(teacher: user, school:, primary: true)
        assert_nil ReferralQuery.new.call(teacher_id: user.id, school_id: school.id)
      end

      test "two queries, whatever the number of referees" do
        teacher = create_teacher
        school_id = Orm::TeacherSchool.find_by!(teacher:).school_id
        3.times { create_referral(referrer: teacher) }
        count = 0
        ActiveSupport::Notifications.subscribed(->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }, "sql.active_record") do
          ReferralQuery.new.call(teacher_id: teacher.id, school_id:)
        end

        assert_equal 2, count
      end

      test "the sponsor's name, for the banner of the sign-up" do
        assert_equal "Awa Traoré", ReferralQuery.new.referrer_name(user_id: create_teacher(first_name: "Awa", last_name: "Traoré").id)
        assert_nil ReferralQuery.new.referrer_name(user_id: nil)
      end
    end
  end
end

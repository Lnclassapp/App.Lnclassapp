require "test_helper"

module Repositories
  module Identity
    # CP-01 to CP-04 (ADR-0063): the referrer behind a token, the referral (one per referee), the share of a click.
    class ReferralRepositoryTest < ActiveSupport::TestCase
      Referrer = Ports::Identity::ReferralRepositoryPort::Referrer
      NOW = Time.utc(2026, 9, 28, 10)

      setup { @repository = ReferralRepository.new }

      def token_of(teacher) = Orm::TeacherProfile.find_by!(user: teacher).referral_token

      test "finds the referrer of a token with its primary school and whether it is active" do
        school = create_school
        teacher = create_teacher(school:)
        closed = create_teacher(school: create_school(status: "inactive"))

        assert_equal Referrer.new(user_id: teacher.id, school_id: school.id, school_active: true),
                     @repository.find_referrer(token: token_of(teacher))
        assert_not @repository.find_referrer(token: token_of(closed)).school_active
      end

      test "a teacher without primary school is a referrer without school; an unknown token is nobody" do
        pending = create_teacher(school: nil)

        assert_equal Referrer.new(user_id: pending.id, school_id: nil, school_active: false),
                     @repository.find_referrer(token: token_of(pending))
        assert_nil @repository.find_referrer(token: "ffffffffffff")
      end

      test "records a referral once per referee; a second one is a conflict that leaves the first" do
        referrer = create_teacher
        referee = create_teacher
        school_id = Orm::TeacherSchool.find_by!(teacher: referrer).school_id

        assert @repository.record_referral(referrer_id: referrer.id, referee_id: referee.id, school_id:, source: "link", at: NOW).success?
        result = @repository.record_referral(referrer_id: create_teacher.id, referee_id: referee.id, school_id:, source: "sponsor", at: NOW)

        assert_equal :conflict, result.code
        assert_equal [ [ referrer.id, "link", NOW ] ], Orm::Referral.where(referee:).pluck(:referrer_id, :source, :created_at)
      end

      test "m6: the referral token of a teacher, nil without profile" do
        teacher = create_teacher

        assert_equal token_of(teacher), @repository.referral_token_for(user_id: teacher.id)
        assert_nil @repository.referral_token_for(user_id: create_user(role: "teacher").id)
      end

      test "records a share with its channel and time, nothing else" do
        teacher = create_teacher

        assert @repository.record_share(user_id: teacher.id, channel: "sms", at: NOW).success?
        assert_equal [ [ teacher.id, "sms", NOW ] ], Orm::ReferralShare.pluck(:user_id, :channel, :created_at)
      end
    end
  end
end

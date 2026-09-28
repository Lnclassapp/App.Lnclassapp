# Referrals, shares and join requests of the growth loops (ADR-0063): a referee has one referrer; a join request is a
# teacher without a primary school, waiting for the team or a colleague of the school.
module Factories
  module Growth
    ActiveSupport::TestCase.include(self)

    def create_referral(referrer: create_teacher, referee: create_teacher, school_id: nil, source: "link", created_at: Time.current)
      school_id ||= Orm::TeacherSchool.find_by!(teacher: referrer, primary: true).school_id
      Orm::Referral.create!(referrer:, referee:, school_id:, source:, created_at:)
    end

    def create_referral_share(user: create_teacher, channel: "whatsapp", created_at: Time.current)
      Orm::ReferralShare.create!(user:, channel:, created_at:)
    end

    def create_join_request(school: create_school, teacher: create_teacher(school: nil), status: "pending", **attributes)
      decided = status == "pending" ? {} : { decided_at: Time.current, decided_via: "team" }
      Orm::SchoolJoinRequest.create!(school:, teacher:, status:, **decided, **attributes)
    end
  end
end

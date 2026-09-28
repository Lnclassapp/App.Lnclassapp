# 🔌 INFRA · Queries::Identity::ReferralQuery
# Rôle : bloc « Inviter un collègue » : école principale, son code, jeton du parrain et nombre de filleuls (lecture seule)
# ADR  : 0057, 0063 · UDR : 0050
module Queries
  module Identity
    class ReferralQuery
      Row = Data.define(:school_name, :school_code, :referral_token, :referred_count)

      # → Row | nil (sans école principale ou sans profil enseignant)
      def call(teacher_id:)
        school_name, school_code, referral_token =
          Orm::TeacherProfile.joins("JOIN teacher_schools ON teacher_schools.teacher_id = teacher_profiles.user_id " \
                                    "AND teacher_schools.primary JOIN schools ON schools.id = teacher_schools.school_id")
                             .where(user_id: teacher_id).pick("schools.name", "schools.school_code", :referral_token)
        return if school_name.nil?

        Row.new(school_name:, school_code:, referral_token:, referred_count: Orm::Referral.where(referrer_id: teacher_id).count)
      end
    end
  end
end

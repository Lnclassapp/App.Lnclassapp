# 🔌 INFRA · Queries::Identity::ReferralQuery
# Rôle : bloc « Inviter un collègue » : école principale, jeton du parrain (lien /i/<jeton>) et nombre de filleuls (lecture seule)
# ADR  : 0063, 0083 · UDR : 0050, 0079
module Queries
  module Identity
    class ReferralQuery
      Row = Data.define(:school_name, :referral_token, :referred_count)

      # → Row | nil (sans école principale ou sans profil enseignant)
      def call(teacher_id:)
        school_name, referral_token =
          Orm::TeacherProfile.joins("JOIN teacher_schools ON teacher_schools.teacher_id = teacher_profiles.user_id " \
                                    "AND teacher_schools.primary JOIN schools ON schools.id = teacher_schools.school_id")
                             .where(user_id: teacher_id).pick("schools.name", :referral_token)
        return if school_name.nil?

        Row.new(school_name:, referral_token:, referred_count: Orm::Referral.where(referrer_id: teacher_id).count)
      end
    end
  end
end

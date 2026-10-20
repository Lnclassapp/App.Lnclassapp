# 🔌 INFRA · Queries::Identity::ReferralQuery
# Rôle : bloc « Inviter un collègue » : établissement courant et son lien, lien de parrainage, nombre de filleuls (lecture seule)
# ADR  : 0063, 0083, 0094 (§11) · UDR : 0050, 0079, 0098 (§3.6)
module Queries
  module Identity
    class ReferralQuery
      # school_token : le lien « Inviter un collègue de mon établissement » (teacher_schools.invite_token de l'établissement
      # courant) ; referral_token : le lien de parrainage, sans établissement (ADR-0094 §11).
      Row = Data.define(:school_name, :school_token, :referral_token, :referred_count)

      # school_id : l'établissement courant (actor.school_id). → Row | nil (non rattaché à cet établissement, ou sans profil)
      def call(teacher_id:, school_id:)
        school_name, school_token, referral_token =
          Orm::TeacherSchool.joins(:school).joins("JOIN teacher_profiles ON teacher_profiles.user_id = teacher_schools.teacher_id")
                            .where(teacher_id:, school_id:).pick("schools.name", :invite_token, "teacher_profiles.referral_token")
        return if school_name.nil?

        Row.new(school_name:, school_token:, referral_token:, referred_count: Orm::Referral.where(referrer_id: teacher_id).count)
      end

      # Le prénom et le nom du collègue qui parraine, pour le bandeau de l'inscription. → String | nil
      def referrer_name(user_id:) = Orm::User.where(id: user_id).pick(:first_name, :last_name)&.join(" ")
    end
  end
end

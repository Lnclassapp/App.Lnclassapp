# 🔌 INFRA · Repositories::Identity::ReferralRepository
# Rôle : parrain d'un jeton (avec son école principale), parrainage unique par filleul, partage d'un lien
# ADR  : 0063
module Repositories
  module Identity
    class ReferralRepository
      include Ports::Identity::ReferralRepositoryPort

      ACTIVE = "active".freeze
      PRIMARY_SCHOOL = "LEFT JOIN teacher_schools ON teacher_schools.teacher_id = teacher_profiles.user_id " \
                       "AND teacher_schools.primary LEFT JOIN schools ON schools.id = teacher_schools.school_id".freeze

      def find_referrer(token:)
        user_id, school_id, status = Orm::TeacherProfile.joins(PRIMARY_SCHOOL).where(referral_token: token)
                                                        .pick(:user_id, "teacher_schools.school_id", "schools.status")
        user_id && Referrer.new(user_id:, school_id:, school_active: status == ACTIVE)
      end

      # Savepoint : un filleul déjà parrainé devient :conflict sans casser la transaction du use case.
      def record_referral(referrer_id:, referee_id:, school_id:, source:, at:)
        Orm::Referral.transaction(requires_new: true) do
          Orm::Referral.create!(referrer_id:, referee_id:, school_id:, source:, created_at: at)
        end
        ::Shared::Result.success
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict)
      end

      def record_share(user_id:, channel:, at:)
        Orm::ReferralShare.create!(user_id:, channel:, created_at: at)
        ::Shared::Result.success
      end
    end
  end
end

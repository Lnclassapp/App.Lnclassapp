# 🔌 INFRA · Repositories::Identity::TeacherProfileRepository
# Rôle : lit le profil enseignant et clôt son onboarding
# ADR  : 0027, 0030
module Repositories
  module Identity
    class TeacherProfileRepository
      include Ports::Identity::TeacherProfileRepositoryPort

      def find_by_user_id(user_id:)
        record = Orm::TeacherProfile.find_by(user_id:)
        return if record.nil?

        Entities::Identity::TeacherProfile.new(user_id: record.user_id, material_id: record.material_id,
                                               onboarding_completed_at: record.onboarding_completed_at)
      end

      # Idempotent : une date déjà posée n'est jamais déplacée.
      def complete_onboarding(user_id:, at:)
        Orm::TeacherProfile.where(user_id:, onboarding_completed_at: nil).update_all(onboarding_completed_at: at, updated_at: at)
        true
      end
    end
  end
end

# 🔌 INFRA · Repositories::Communication::PushPreferenceRepository
# Rôle : préférence de l'élève en base (push_preferences, une ligne par compte) : interrupteur « coupé » et report de la carte d'invitation
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.1, §4.2) · adaptateur de Ports::Communication::PushPreferenceRepositoryPort
module Repositories
  module Communication
    class PushPreferenceRepository
      include Ports::Communication::PushPreferenceRepositoryPort

      def turned_off?(user_id:) = Orm::Communication::PushPreference.where(user_id:).where.not(turned_off_at: nil).exists?

      # Chaque écriture ne touche que sa colonne : couper ne défait pas un report, et inversement.
      def turn_off(user_id:, at:)
        Orm::Communication::PushPreference.upsert({ user_id:, turned_off_at: at }, unique_by: :user_id)
      end

      def turn_on(user_id:) = Orm::Communication::PushPreference.where(user_id:).update_all(turned_off_at: nil)

      def postpone_invitation(user_id:, until_time:)
        Orm::Communication::PushPreference.upsert({ user_id:, invitation_postponed_until: until_time }, unique_by: :user_id)
      end

      def invitation_postponed_until(user_id:) = Orm::Communication::PushPreference.where(user_id:).pick(:invitation_postponed_until)
    end
  end
end

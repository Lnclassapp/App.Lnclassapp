# 🔌 INFRA · Queries::Communication::PushInvitationQuery
# Rôle : lecture de la carte d'invitation (sous un résultat réussi) et de l'état de la ligne « Notifications » du profil
# ADR  : 0146 (§4.4) · UDR : 0186 (§3.1, §3.2)
module Queries
  module Communication
    class PushInvitationQuery
      # shell : la page tourne dans la coque Android (reconnue par l'appelant, qui lit l'agent utilisateur).
      def show?(student_id:, score_percent:, shell: false, now: Time.current)
        return false if shell || !Entities::Assessment::Grading.reaches?(score_percent, Entities::Assessment::Grading::PASS_THRESHOLD)
        return false if subscriptions(student_id).exists?

        preference = Orm::Communication::PushPreference.find_by(user_id: student_id)
        return true if preference.nil?

        preference.turned_off_at.nil? && (preference.invitation_postponed_until.nil? || preference.invitation_postponed_until <= now)
      end

      # → :hidden (jamais touché « Oui » : ni abonnement, ni coupé ; ou coque Android) | :off | :on.
      # Le navigateur précise « sur cet appareil / sur un autre / bloquées » (permission et abonnement locaux).
      def profile_state(student_id:, shell: false)
        return :hidden if shell
        return :off if Orm::Communication::PushPreference.where(user_id: student_id).where.not(turned_off_at: nil).exists?

        subscriptions(student_id).exists? ? :on : :hidden
      end

      private

      def subscriptions(student_id) = Orm::Communication::PushSubscription.where(user_id: student_id)
    end
  end
end

# 🧠 DOMAINE · Ports::Communication::PushPreferenceRepositoryPort
# Rôle : contrat de la préférence de l'élève : interrupteur « coupé » et report de la carte d'invitation
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.2)
module Ports
  module Communication
    module PushPreferenceRepositoryPort
      def turned_off?(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #turned_off?"
      end

      def turn_off(user_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #turn_off"
      end

      def turn_on(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #turn_on"
      end

      def postpone_invitation(user_id:, until_time:)
        raise NotImplementedError, "#{self.class} doit implémenter #postpone_invitation"
      end

      # → Time | nil
      def invitation_postponed_until(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #invitation_postponed_until"
      end
    end
  end
end

# 🧠 DOMAINE · Ports::Identity::ReferralRepositoryPort
# Rôle : contrat du parrainage : parrain d'un jeton, filleul (un seul parrain), partage d'un lien
# ADR  : 0063
module Ports
  module Identity
    module ReferralRepositoryPort
      # school_id : école principale du parrain (nil sans école) ; school_active : cette école est active.
      Referrer = Data.define(:user_id, :school_id, :school_active)

      # → Referrer | nil
      def find_referrer(token:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_referrer"
      end

      # source : "link" | "sponsor". → Result | failure(:conflict) (le filleul a déjà un parrain)
      def record_referral(referrer_id:, referee_id:, school_id:, source:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #record_referral"
      end

      # channel ∈ Entities::Identity::ShareChannel::ALL. → Result
      def record_share(user_id:, channel:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #record_share"
      end
    end
  end
end

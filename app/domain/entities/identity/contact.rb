# 🧠 DOMAINE · Entities::Identity::Contact
# Rôle : normalise un numéro ivoirien en 10 chiffres, ou renvoie nil ; le masque pour un écran d'agrégats
# ADR  : 0050, 0062
module Entities
  module Identity
    module Contact
      FORMAT = /\A0[157]\d{8}\z/

      def self.normalize(raw)
        digits = raw.to_s.gsub(/\D/, "")
        digits = digits.delete_prefix("00225") if digits.length == 15
        digits = digits.delete_prefix("225") if digits.length == 13
        digits if digits.match?(FORMAT)
      end

      # Minimisation (ADR-0062) : un écran d'agrégats ne montre que les deux premiers et les deux derniers chiffres.
      def self.mask(contact)
        return if contact.blank?

        "#{contact[0, 2]} •• •• •• #{contact[-2, 2]}"
      end
    end
  end
end

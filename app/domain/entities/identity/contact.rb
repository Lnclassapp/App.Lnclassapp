# 🧠 DOMAINE · Entities::Identity::Contact
# Rôle : normalise un numéro ivoirien en 10 chiffres, ou renvoie nil
# ADR  : 0050
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
    end
  end
end

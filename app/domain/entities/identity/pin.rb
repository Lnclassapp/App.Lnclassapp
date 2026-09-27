# 🧠 DOMAINE · Entities::Identity::Pin
# Rôle : format du PIN à 4 chiffres ; jamais dérivé du contact, jamais stocké dans une entité
# ADR  : 0025, 0050
module Entities
  module Identity
    module Pin
      FORMAT = /\A\d{4}\z/

      def self.valid?(raw) = raw.is_a?(String) && raw.match?(FORMAT)
    end
  end
end

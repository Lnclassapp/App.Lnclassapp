# 🧠 DOMAINE · Entities::Identity::ReferralToken
# Rôle : jeton de parrainage opaque d'un enseignant (12 caractères hexadécimaux, tiré par la base) ; seule sa forme est lue ici
# ADR  : 0063 · UDR : 0050
module Entities
  module Identity
    module ReferralToken
      FORMAT = /\A[0-9a-f]{12}\z/

      # « 0A1B… » saisi ou recopié → « 0a1b… » ; toute autre forme → nil, sans recherche.
      def self.normalize(raw)
        token = raw.to_s.strip.downcase
        token if FORMAT.match?(token)
      end
    end
  end
end

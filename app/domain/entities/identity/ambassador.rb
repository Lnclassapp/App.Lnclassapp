# 🧠 DOMAINE · Entities::Identity::Ambassador
# Rôle : badge « Ambassadeur » d'un enseignant, levier sans argent, à partir de 3 collègues inscrits grâce à lui
# ADR  : 0063 · UDR : 0050
module Entities
  module Identity
    module Ambassador
      # Défaut à confirmer par le porteur (ADR-0063).
      THRESHOLD = 3

      def self.ambassador?(referred_count:) = referred_count >= THRESHOLD
    end
  end
end

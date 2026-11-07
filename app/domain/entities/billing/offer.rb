# 🧠 DOMAINE · Entities::Billing::Offer
# Rôle : l'offre de lancement, prix d'une carte, fin d'abonnement, mise en ligne, jours gratuits et commissions
# ADR  : cartes-activation (contexte billing, §4.8)
module Entities
  module Billing
    module Offer
      PRICE_XOF = 10_000
      VALID_UNTIL = Date.new(2027, 7, 31)
      LAUNCH_ON = Date.new(2026, 11, 9)
      FREE_DAYS = 7
      RELAY_COMMISSION_XOF = 200
      SCHOOL_COMMISSION_XOF = 1_000
    end
  end
end

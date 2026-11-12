# 🧠 DOMAINE · Entities::Billing::Offer
# Rôle : l'offre de lancement, prix d'une carte, fin d'abonnement, mise en ligne, jours gratuits, commissions et bêta ouverte
# ADR  : 0126 (contexte billing, §4.8), acces-beta (BETA_ENDS_ON)
module Entities
  module Billing
    module Offer
      PRICE_XOF = 10_000
      VALID_UNTIL = Date.new(2027, 7, 31)
      LAUNCH_ON = Date.new(2026, 11, 9)
      FREE_DAYS = 7
      RELAY_COMMISSION_XOF = 200
      SCHOOL_COMMISSION_XOF = 1_000
      # Bêta (décision du porteur, 2026-11-12) : tant que nil, ou avant cette date, tout élève a l'accès complet gratuit,
      # sans bandeau ni blocage. Le seul réglage à poser (une date) pour fermer la bêta : à partir d'elle, chaque élève
      # reçoit ses FREE_DAYS jours gratuits, puis l'abonnement s'applique (ADR acces-beta ; LAUNCH_ON reporté à la fin de bêta).
      BETA_ENDS_ON = nil
    end
  end
end

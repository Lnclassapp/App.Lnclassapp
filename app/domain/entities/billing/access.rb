# 🧠 DOMAINE · Entities::Billing::Access
# Rôle : l'accès d'un élève, bêta, gratuit (jours restants), abonné ou bloqué ; calculé, jamais stocké
# ADR  : 0126 (contexte billing, §4.5 et §6), acces-beta
module Entities
  module Billing
    Access = Data.define(:status, :days_left, :subscribed_until) do
      # beta : lu à chaque appel sur Offer::BETA_OPEN_ACCESS ; un abonné reste abonné (sa date reste affichée).
      def self.for(account_created_on:, today:, subscribed_until:, beta: Offer::BETA_OPEN_ACCESS)
        return new(status: :subscribed, days_left: nil, subscribed_until:) if subscribed_until && subscribed_until >= today
        return new(status: :beta, days_left: nil, subscribed_until: nil) if beta

        starts_on = [ account_created_on, Offer::LAUNCH_ON ].max
        days_left = Offer::FREE_DAYS - (today - starts_on).to_i
        days_left.positive? ? new(status: :free, days_left:, subscribed_until: nil) : new(status: :blocked, days_left: 0, subscribed_until: nil)
      end

      # Hors élève (enseignant, direction, équipe) ou compte inconnu : jamais bloqué.
      def self.unrestricted = new(status: :subscribed, days_left: nil, subscribed_until: nil)

      def blocked? = status == :blocked

      # Gratuit ou bloqué : l'élève est invité à s'abonner (bandeau de l'accueil). Ni en bêta, ni abonné.
      def subscription_pending? = status == :free || status == :blocked
    end
  end
end

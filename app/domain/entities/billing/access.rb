# 🧠 DOMAINE · Entities::Billing::Access
# Rôle : l'accès d'un élève, gratuit (jours restants), abonné ou bloqué ; calculé, jamais stocké
# ADR  : cartes-activation (contexte billing, §4.5 et §6)
module Entities
  module Billing
    Access = Data.define(:status, :days_left, :subscribed_until) do
      def self.for(account_created_on:, today:, subscribed_until:)
        return new(status: :subscribed, days_left: nil, subscribed_until:) if subscribed_until && subscribed_until >= today

        starts_on = [ account_created_on, Offer::LAUNCH_ON ].max
        days_left = Offer::FREE_DAYS - (today - starts_on).to_i
        days_left.positive? ? new(status: :free, days_left:, subscribed_until: nil) : new(status: :blocked, days_left: 0, subscribed_until: nil)
      end

      # Hors élève (enseignant, direction, équipe) ou compte inconnu : jamais bloqué.
      def self.unrestricted = new(status: :subscribed, days_left: nil, subscribed_until: nil)

      def blocked? = status == :blocked
    end
  end
end

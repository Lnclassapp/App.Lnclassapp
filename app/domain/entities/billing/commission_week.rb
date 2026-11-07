# 🧠 DOMAINE · Entities::Billing::CommissionWeek
# Rôle : une semaine de commission, du vendredi 00:00 au jeudi 23:59 (Africa/Abidjan = UTC) ; 200 F par activation payante
# ADR  : cartes-activation (contexte billing, §4.7)
module Entities
  module Billing
    CommissionWeek = Data.define(:starts_on) do
      FRIDAY = 5

      # La semaine qui contient l'instant donné.
      def self.containing(time)
        date = time.utc.to_date
        new(starts_on: date - ((date.wday - FRIDAY) % 7))
      end

      # La dernière semaine terminée : celle que l'équipe paie le vendredi.
      def self.previous(at:) = new(starts_on: containing(at).starts_on - 7)

      # Les `count` dernières semaines terminées, de la plus récente à la plus ancienne.
      def self.recent(count, at:)
        last = previous(at:).starts_on
        Array.new(count) { |index| new(starts_on: last - (7 * index)) }
      end

      def ends_on = starts_on + 6
      def starts_at = Time.utc(starts_on.year, starts_on.month, starts_on.day)
      # Borne exclue : le vendredi suivant à 00:00.
      def ends_at = starts_at + 7.days
      def cover?(time) = time >= starts_at && time < ends_at
      def commission_xof(activations) = activations * Offer::RELAY_COMMISSION_XOF
    end
  end
end

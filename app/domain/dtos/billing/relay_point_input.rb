# 🧠 DOMAINE · Dtos::Billing::RelayPointInput
# Rôle : forme d'un point relais saisi à l'écran : nom (80), lieu (120), téléphone de dix chiffres, écoles, actif
# ADR  : 0126 (contexte billing, §4.1) · UDR : 0159 §3.2
module Dtos
  module Billing
    class RelayPointInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      NAME_MAX = 80
      LOCATION_MAX = 120
      PHONE_DIGITS = 10

      attribute :name, :string
      attribute :location, :string
      attribute :phone, :string
      attribute :active, :boolean, default: true
      attribute :school_ids

      validates :name, presence: true, length: { maximum: NAME_MAX }
      validates :location, presence: true, length: { maximum: LOCATION_MAX }
      validate :phone_has_ten_digits

      def name = super.to_s.squish.presence
      def location = super.to_s.squish.presence

      # « 0700000000 » ou « 07.00.00.00.00 » deviennent « 07 00 00 00 00 » ; un numéro qui n'a pas dix chiffres reste tel que saisi.
      def phone
        raw = super.to_s.squish
        digits = raw.delete("^0-9")
        digits.length == PHONE_DIGITS && raw.match?(/\A[\d .-]+\z/) ? digits.scan(/../).join(" ") : raw.presence
      end

      # Cases cochées : le champ caché envoie "" ; chaque identifiant est un entier positif, une fois.
      def school_ids = Array(super).filter_map { Integer(it.to_s, exception: false) }.select(&:positive?).uniq

      private

      def phone_has_ten_digits
        errors.add(:phone, phone.nil? ? :blank : :invalid) unless phone&.match?(/\A(\d\d )\d\d \d\d \d\d \d\d\z/)
      end
    end
  end
end

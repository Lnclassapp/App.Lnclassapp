# 🧠 DOMAINE · Dtos::Billing::RemittanceInput
# Rôle : forme d'un versement saisi à l'écran : montant entier signé non nul, motif requis s'il est négatif, référence de 60 caractères au plus
# ADR  : cartes-activation (contexte billing, §4.1) · UDR : caisse-equipe §3.6
module Dtos
  module Billing
    class RemittanceInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      REFERENCE_MAX = 60
      REASON_MAX = 200
      MINUS_SIGNS = /[−–—]/
      AMOUNT_FORMAT = /\A-?\d{1,9}\z/

      attribute :relay_point_public_id, :string
      attribute :amount_xof, :string
      attribute :received_at, :datetime
      attribute :reference, :string
      attribute :reason, :string

      validates :relay_point_public_id, presence: true
      validates :amount_xof, presence: true
      validate :amount_is_a_signed_integer
      validate :received_at_is_readable
      validates :reference, length: { maximum: REFERENCE_MAX }
      validates :reason, length: { maximum: REASON_MAX }
      validates :reason, presence: true, if: :correction?

      # Le montant tapé peut porter des espaces (« 10 000 ») et un vrai signe moins ; rendu entier, ou nil s'il n'en est pas un.
      def amount
        cleaned = amount_xof.to_s.gsub(MINUS_SIGNS, "-").gsub(/[[:space:]]/, "")
        Integer(cleaned, 10) if cleaned.match?(AMOUNT_FORMAT)
      end

      def reference = super.to_s.squish.presence
      def reason = super.to_s.squish.presence
      def correction? = amount&.negative? || false

      private

      # Une date tapée mais illisible devient nil au cast : elle ne doit pas se changer en silence en « reçu maintenant ».
      def received_at_is_readable
        typed = @attributes["received_at"].value_before_type_cast
        errors.add(:received_at, :invalid) if typed.present? && received_at.nil?
      end

      def amount_is_a_signed_integer
        return if amount_xof.blank?

        errors.add(:amount_xof, :not_an_integer) if amount.nil?
        errors.add(:amount_xof, :other_than, count: 0) if amount&.zero?
      end
    end
  end
end

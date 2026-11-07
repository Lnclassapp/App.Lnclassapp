# 🧠 DOMAINE · Dtos::Billing::CardBatchInput
# Rôle : forme d'un lot de cartes saisi à l'écran : quantité de 1 à 200, prix de l'offre ou offert (0 F)
# ADR  : cartes-activation (contexte billing, §4.1 et §4.8) · UDR : caisse-equipe §3.3
module Dtos
  module Billing
    class CardBatchInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      PRICES = [ Entities::Billing::Offer::PRICE_XOF, 0 ].freeze

      attribute :quantity, :integer
      attribute :unit_price_xof, :integer, default: Entities::Billing::Offer::PRICE_XOF

      validates :quantity, numericality: { only_integer: true, in: 1..Entities::Billing::CardBatch::MAX_QUANTITY }
      validates :unit_price_xof, inclusion: { in: PRICES }
    end
  end
end

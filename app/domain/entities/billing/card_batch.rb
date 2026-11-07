# 🧠 DOMAINE · Entities::Billing::CardBatch
# Rôle : un lot de cartes créé pour un point relais, à un prix figé (0 = offert)
# ADR  : cartes-activation (contexte billing, §4.1)
module Entities
  module Billing
    CardBatch = Data.define(:id, :public_id, :relay_point_id, :quantity, :unit_price_xof, :valid_until, :created_by_id, :created_at,
                            :cards) do
      def initialize(id: nil, public_id: nil, relay_point_id: nil, quantity: 0, unit_price_xof: 0, valid_until: nil, created_by_id: nil,
                     created_at: nil, cards: []) = super
    end
    CardBatch::MAX_QUANTITY = 200
  end
end

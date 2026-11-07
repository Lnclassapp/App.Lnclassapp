# 🔌 INFRA · Orm::Billing::CardBatch
# Rôle : table billing_card_batches, un lot de cartes créé pour un point relais à un prix figé (0 = offert)
# ADR  : 0126 (contexte billing, §4.1)
module Orm
  module Billing
    class CardBatch < ApplicationRecord
      include Orm::HasPublicId

      self.table_name = "billing_card_batches"

      belongs_to :relay_point, class_name: "Orm::Billing::RelayPoint", inverse_of: :card_batches
      belongs_to :created_by, class_name: "Orm::User", optional: true
      has_many :cards, class_name: "Orm::Billing::ActivationCard", foreign_key: :batch_id, inverse_of: :batch,
                       dependent: :restrict_with_error
    end
  end
end

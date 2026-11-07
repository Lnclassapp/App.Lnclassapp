# 🔌 INFRA · Orm::Billing::ActivationCard
# Rôle : table billing_activation_cards, code chiffré de façon déterministe (ADR-0031) : recherche par égalité, jamais lisible en base
# ADR  : cartes-activation (contexte billing, §4.1 et §4.2), 0031
module Orm
  module Billing
    class ActivationCard < ApplicationRecord
      include Orm::HasPublicId

      self.table_name = "billing_activation_cards"

      encrypts :code, deterministic: true

      belongs_to :batch, class_name: "Orm::Billing::CardBatch", inverse_of: :cards
      belongs_to :relay_point, class_name: "Orm::Billing::RelayPoint"
      belongs_to :student, class_name: "Orm::User", optional: true
      belongs_to :school, class_name: "Orm::School", optional: true
      belongs_to :cancelled_by, class_name: "Orm::User", optional: true
    end
  end
end

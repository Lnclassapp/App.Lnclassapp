# 🧠 DOMAINE · Entities::Billing::Remittance
# Rôle : un versement d'un point relais, entier signé, jamais modifié ni supprimé ; une erreur se corrige par un versement négatif
# ADR  : cartes-activation (contexte billing, §4.1)
module Entities
  module Billing
    Remittance = Data.define(:id, :public_id, :relay_point_id, :amount_xof, :received_at, :reference, :reason, :recorded_by_id,
                             :created_at) do
      def initialize(id: nil, public_id: nil, relay_point_id: nil, amount_xof: 0, received_at: nil, reference: nil, reason: nil,
                     recorded_by_id: nil, created_at: nil) = super

      def correction? = amount_xof.negative?
    end
  end
end

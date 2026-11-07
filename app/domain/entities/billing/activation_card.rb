# 🧠 DOMAINE · Entities::Billing::ActivationCard
# Rôle : une carte d'activation, remise, activée ou annulée ; activée, elle est l'abonnement de l'élève
# ADR  : cartes-activation (contexte billing, §4)
module Entities
  module Billing
    ActivationCard = Data.define(:id, :public_id, :batch_id, :relay_point_id, :serial, :code, :price_xof, :valid_until, :state,
                                 :student_id, :school_id, :activated_at, :cancelled_at, :cancelled_by_id, :cancel_reason) do
      def initialize(id: nil, public_id: nil, batch_id: nil, relay_point_id: nil, serial: nil, code: nil, price_xof: 0, valid_until: nil,
                     state: "issued", student_id: nil, school_id: nil, activated_at: nil, cancelled_at: nil, cancelled_by_id: nil,
                     cancel_reason: nil) = super

      def issued? = state == "issued"
      def activated? = state == "activated"
      def cancelled? = state == "cancelled"
      # Une carte offerte (prix 0) abonne mais ne compte ni dans le dû ni dans les commissions.
      def paid? = price_xof.positive?
      def serial_label = serial.to_s.rjust(6, "0")
      def display_code = ActivationCode.format(code)
    end
    ActivationCard::STATES = %w[issued activated cancelled].freeze
  end
end

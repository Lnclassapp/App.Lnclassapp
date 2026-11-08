require "test_helper"

module Entities
  module Billing
    class EntitiesTest < ActiveSupport::TestCase
      test "l'offre porte les montants et dates de l'ADR" do
        assert_equal 10_000, Offer::PRICE_XOF
        assert_equal Date.new(2027, 7, 31), Offer::VALID_UNTIL
        assert_equal Date.new(2026, 11, 9), Offer::LAUNCH_ON
        assert_equal 7, Offer::FREE_DAYS
        assert_equal 200, Offer::RELAY_COMMISSION_XOF
        assert_equal 1_000, Offer::SCHOOL_COMMISSION_XOF
      end

      test "une carte lit son état, son prix et ses libellés" do
        card = ActivationCard.new(serial: 21, code: "K7QHM3XP9TRA", price_xof: 10_000, state: "issued")

        assert_predicate card, :issued?
        assert_predicate card, :paid?
        assert_equal "000021", card.serial_label
        assert_equal "K7QH-M3XP-9TRA", card.display_code
        assert_predicate ActivationCard.new(state: "activated", price_xof: 0), :activated?
        assert_not ActivationCard.new(state: "activated", price_xof: 0).paid?
        assert_predicate ActivationCard.new(state: "cancelled"), :cancelled?
      end

      test "un versement négatif est une correction" do
        assert_predicate Remittance.new(amount_xof: -10_000), :correction?
        assert_not Remittance.new(amount_xof: 10_000).correction?
      end

      test "un point relais, un lot ont des valeurs par défaut sûres" do
        assert_equal [], RelayPoint.new(name: "Awa").school_ids
        assert_predicate RelayPoint.new(name: "Awa"), :active
        assert_equal [], CardBatch.new(quantity: 2).cards
      end
    end
  end
end

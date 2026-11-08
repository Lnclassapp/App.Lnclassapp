require "test_helper"

# Les fixtures du Lot 0 de cartes-activation portent le scénario Caisse du PRD ; l'ORM déchiffre leurs codes.
class BillingFixturesTest < ActiveSupport::TestCase
  test "la Boutique Awa a 20 cartes : 3 activées, 2 annulées, 15 remises, 20 000 F versés" do
    awa = Orm::Billing::RelayPoint.find_by!(name: "Boutique Awa")
    cards = Orm::Billing::ActivationCard.where(relay_point_id: awa.id)

    assert_equal({ "activated" => 3, "cancelled" => 2, "issued" => 15 }, cards.group(:state).count)
    assert_equal 30_000, cards.where(state: "activated").sum(:price_xof)
    assert_equal 20_000, Orm::Billing::Remittance.where(relay_point_id: awa.id).sum(:amount_xof)
    assert(cards.all? { Entities::Billing::ActivationCode.well_formed?(it.code) })
  end

  test "un code de fixture se retrouve par égalité" do
    code = Orm::Billing::ActivationCard.find_by!(public_id: "AwaCard0000006").code

    assert_equal "issued", Orm::Billing::ActivationCard.find_by!(code:).state
  end

  test "un versement ne se modifie ni ne se supprime" do
    remittance = Orm::Billing::Remittance.first

    assert_not remittance.update(reference: "autre")
    assert_not remittance.destroy
  end
end

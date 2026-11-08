require "test_helper"

# cartes-activation, revues du Lot E : un visiteur non connecté est renvoyé à la connexion sur chaque écran de facturation.
class BillingVisitorAccessTest < ActionDispatch::IntegrationTest
  test "activer une carte sans être connecté mène à la connexion, rien n'est activé" do
    assert_no_difference -> { Orm::Billing::ActivationCard.where(state: "activated").count } do
      post billing_activation_path, params: { code: "K7QHM3XP9TRA" }
    end

    assert_redirected_to new_session_path
  end

  test "les écrans de l'équipe mènent à la connexion" do
    awa = Orm::Billing::RelayPoint.find_by!(name: "Boutique Awa")

    get teams_billing_card_cancellation_path
    assert_redirected_to new_session_path
    post teams_billing_card_cancellation_path, params: { serial: 1, cancellation: { reason: "perdue" } }
    assert_redirected_to new_session_path
    get teams_billing_relay_points_path
    assert_redirected_to new_session_path
    post teams_billing_relay_points_path, params: { relay_point: { name: "X" } }
    assert_redirected_to new_session_path
    get new_teams_billing_remittance_path
    assert_redirected_to new_session_path
    post teams_billing_remittances_path, params: { remittance: { relay_point_public_id: awa.public_id, amount_xof: "5000" } }
    assert_redirected_to new_session_path
    post teams_billing_relay_point_card_batches_path(awa.public_id), params: { card_batch: { quantity: "1", unit_price_xof: "0" } }
    assert_redirected_to new_session_path
  end
end

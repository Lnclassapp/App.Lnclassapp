require "test_helper"

# Lot 0 de cartes-activation : les routes sont dessinées avant les contrôleurs des lots A, B et C.
class BillingRoutesTest < ActionDispatch::IntegrationTest
  # recognize_path exige que le contrôleur existe ; les lots A, B et C les écrivent après ce lot : on lit la table des routes.
  def assert_route(expected, path, method: :get)
    route = Rails.application.routes.routes.find { it.verb == method.to_s.upcase && it.path.to_regexp.match?(path) }

    assert route, "aucune route #{method.to_s.upcase} #{path}"
    assert_equal expected, route.requirements.slice(*expected.keys)
  end

  test "l'élève a Mon abonnement et la saisie du code" do
    assert_equal "/abonnement", billing_subscription_path
    assert_equal "/abonnement/activation", billing_activation_path
    assert_route({ controller: "billing/subscriptions", action: "show" }, "/abonnement")
    assert_route({ controller: "billing/activations", action: "create" }, "/abonnement/activation", method: :post)
  end

  test "l'équipe a la caisse, les points relais, les lots, les annulations et les versements" do
    assert_route({ controller: "teams/billing/cashboxes", action: "show" }, "/teams/caisse")
    assert_route({ controller: "teams/billing/relay_points", action: "index" }, "/teams/points-relais")
    assert_route({ controller: "teams/billing/relay_points", action: "show" }, "/teams/points-relais/abc")
    assert_route({ controller: "teams/billing/card_batches", action: "new" }, "/teams/points-relais/abc/lots/new")
    assert_route({ controller: "teams/billing/card_batches", action: "create" }, "/teams/points-relais/abc/lots", method: :post)
    assert_route({ controller: "teams/billing/card_batches", action: "show" }, "/teams/lots/xyz/planche")
    assert_route({ controller: "teams/billing/card_cancellations", action: "show" }, "/teams/cartes/annuler")
    assert_route({ controller: "teams/billing/card_cancellations", action: "create" }, "/teams/cartes/annuler", method: :post)
    assert_route({ controller: "teams/billing/remittances", action: "new" }, "/teams/versements/new")
    assert_route({ controller: "teams/billing/remittances", action: "create" }, "/teams/versements", method: :post)
  end
end

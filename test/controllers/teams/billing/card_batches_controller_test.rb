require "test_helper"

# UDR caisse-equipe §3.3 et §3.4, PRD §4 « Points relais et lots » : un lot de cartes et sa planche d'impression.
class Teams::Billing::CardBatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    @awa = Orm::Billing::RelayPoint.find_by!(name: "Boutique Awa")
  end

  def batch_params(quantity: "20", price: "10000") = { card_batch: { quantity:, unit_price_xof: price } }

  test "un élève, un enseignant et la direction reçoivent 403 partout" do
    [ create_student, create_teacher, create_user(role: "school_admin") ].each do |user|
      sign_in_as user
      get new_teams_billing_relay_point_card_batch_path(@awa.public_id)
      assert_response :forbidden
      post teams_billing_relay_point_card_batches_path(@awa.public_id), params: batch_params
      assert_response :forbidden
      get teams_billing_card_batch_sheet_path("AwaBatch000001")
      assert_response :forbidden
      sign_out
    end
  end

  test "le formulaire propose la quantité et le prix, 10 000 F ou offert" do
    sign_in_as @member

    get new_teams_billing_relay_point_card_batch_path(@awa.public_id), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "form#card-batch-form" do
      assert_select "input[name='card_batch[quantity]'][type=number][min='1'][max='200']"
      assert_select "input[type=radio][name='card_batch[unit_price_xof]'][value='10000'][checked]"
      assert_select "input[type=radio][name='card_batch[unit_price_xof]'][value='0']"
    end
  end

  test "un lot de 20 cartes à 10 000 F : 20 cartes remises aux numéros et codes uniques, la planche les montre" do
    sign_in_as @member

    assert_difference -> { Orm::Billing::ActivationCard.count } => 20, -> { Orm::AuditEvent.where(action: "billing.card_batch_created").count } => 1 do
      post teams_billing_relay_point_card_batches_path(@awa.public_id), params: batch_params
    end

    batch = Orm::Billing::CardBatch.order(:id).last
    assert_redirected_to teams_billing_card_batch_sheet_path(batch.public_id)
    cards = batch.cards.order(:serial)
    assert_equal [ 20, 20, 10_000 ], [ cards.count, cards.map(&:serial).uniq.size, cards.first.price_xof ]
    assert(cards.all? { Entities::Billing::ActivationCode.well_formed?(it.code) && it.state == "issued" })

    follow_redirect!
    assert_response :success
    assert_select "h1.sr-only"
    assert_select "[data-card]", 20
    assert_select "[data-card]:first-of-type" do
      assert_select "p", text: "N° #{cards.first.serial.to_s.rjust(6, '0')}"
      assert_select "p", text: Entities::Billing::ActivationCode.format(cards.first.code)
      assert_select "p", text: "10 000 F"
    end
    assert_select "[data-controller=print] button[data-action='print#print']", text: "Imprimer"
    assert_select "nav", 0
  end

  test "un lot offert s'imprime « Offerte »" do
    sign_in_as @member

    post teams_billing_relay_point_card_batches_path(@awa.public_id), params: batch_params(quantity: "3", price: "0")
    follow_redirect!

    assert_select "[data-card]", 3
    assert_select "[data-card] p", text: "Offerte", count: 3
  end

  test "une quantité hors de 1 à 200 est refusée en 422, rien n'est créé" do
    sign_in_as @member

    assert_no_difference -> { Orm::Billing::CardBatch.count } do
      post teams_billing_relay_point_card_batches_path(@awa.public_id), params: batch_params(quantity: "201")
    end

    assert_response :unprocessable_content
    assert_select "#card_batch_quantity_error"
  end

  test "un point relais inconnu ou désactivé est refusé" do
    sign_in_as @member

    get new_teams_billing_relay_point_card_batch_path("Inconnu")
    assert_response :not_found
    post teams_billing_relay_point_card_batches_path("Inconnu"), params: batch_params
    assert_response :not_found

    @awa.update!(active: false)
    assert_no_difference -> { Orm::Billing::CardBatch.count } do
      post teams_billing_relay_point_card_batches_path(@awa.public_id), params: batch_params
    end
    assert_response :unprocessable_content
  end

  test "la planche d'un lot inconnu est introuvable ; le lot des fixtures montre ses 20 cartes" do
    sign_in_as @member

    get teams_billing_card_batch_sheet_path("Inconnu")
    assert_response :not_found

    get teams_billing_card_batch_sheet_path("AwaBatch000001")
    assert_select "[data-card]", 20
  end

  test "la planche des codes n'entre dans aucun cache : no-store, Pragma et exemption du cache Turbo" do
    sign_in_as @member

    get teams_billing_card_batch_sheet_path("AwaBatch000001")

    assert_response :success
    assert_match(/no-store/, response.headers["Cache-Control"])
    assert_equal "no-cache", response.headers["Pragma"]
    assert_select "meta[name='turbo-cache-control'][content='no-cache']"
  end

  test "chaque affichage de la planche écrit un audit sans aucun code ; un lot inconnu n'en écrit pas" do
    sign_in_as @member
    batch = Orm::Billing::CardBatch.find_by!(public_id: "AwaBatch000001")

    assert_difference -> { Orm::AuditEvent.where(action: "billing.card_batch_printed").count }, 2 do
      2.times { get teams_billing_card_batch_sheet_path(batch.public_id) }
    end
    event = Orm::AuditEvent.where(action: "billing.card_batch_printed").order(:id).last
    assert_equal @member.id, event.actor_id
    assert_equal batch.id, event.subject_id
    assert_equal batch.relay_point_id, event.metadata["relay_point_id"]
    assert_equal batch.public_id, event.metadata["batch_public_id"]
    codes = batch.cards.map(&:code)
    assert(codes.none? { event.metadata.to_json.include?(it) })

    assert_no_difference -> { Orm::AuditEvent.where(action: "billing.card_batch_printed").count } do
      get teams_billing_card_batch_sheet_path("Inconnu")
    end
  end

  test "un visiteur non connecté est renvoyé à la connexion" do
    get new_teams_billing_relay_point_card_batch_path(@awa.public_id)
    assert_redirected_to new_session_path
    post teams_billing_relay_point_card_batches_path(@awa.public_id), params: batch_params
    assert_redirected_to new_session_path
    get teams_billing_card_batch_sheet_path("AwaBatch000001")
    assert_redirected_to new_session_path
  end
end

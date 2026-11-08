require "test_helper"

# ADR 0126 §4.7, UDR-0159 §3.1 : la caisse de l'équipe, calculée à la lecture.
class Teams::Billing::CashboxesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    @awa = Orm::Billing::RelayPoint.find_by!(name: "Boutique Awa")
  end

  test "a visitor is sent to sign in, a teacher, a student and a school admin receive 403" do
    get teams_billing_cashbox_path
    assert_redirected_to "/login"

    [ create_teacher, create_student, create_user(role: "school_admin") ].each do |user|
      sign_in_as user
      get teams_billing_cashbox_path
      assert_response :forbidden
      sign_out
    end
  end

  test "the cashbox shows what Boutique Awa owes and how many cards are in circulation" do
    travel_to Time.utc(2026, 11, 13, 12) do
      sign_in_as @member
      get teams_billing_cashbox_path
    end

    assert_response :success
    assert_select "h1", "Caisse"
    assert_select "#cashbox_relays tr", text: /Boutique Awa/ do
      assert_select "td.text-error", text: /10 000 F/
      assert_select "td", text: "15"
    end
    assert_select "a[href='#{teams_billing_relay_point_path(@awa.public_id)}']", text: "Boutique Awa"
  end

  test "au téléphone, le reste dû se lit sans défilement : aucun conteneur à défilement, colonnes secondaires masquées" do
    sign_in_as @member
    get teams_billing_cashbox_path

    assert_select "#cashbox_relays .overflow-x-auto, #cashbox_week .overflow-x-auto, #cashbox_schools .overflow-x-auto", count: 0
    assert_select "#cashbox_relays th.hidden.md\\:table-cell", 4
    assert_select "#cashbox_relays th:not(.hidden)", 3
  end

  test "the Friday block names the week and the commission due" do
    travel_to Time.utc(2026, 11, 13, 12) do
      sign_in_as @member
      get teams_billing_cashbox_path
    end

    assert_select "#cashbox_week", text: /du 6 au 12 novembre/
    assert_select "#cashbox_week tr", text: /Boutique Awa.*2.*400 F/m
    assert_select "#cashbox_week", text: /Total.*400 F/m
  end

  test "a week without activation says so" do
    travel_to Time.utc(2026, 11, 27, 12) do
      sign_in_as @member
      get teams_billing_cashbox_path
    end

    assert_select "#cashbox_week", text: /Aucune activation cette semaine-là\./
    assert_select "#cashbox_week details"
  end

  test "the schools block shows the cumulated commission" do
    school = create_school(name: "Collège Saint Michel")
    cards = Repositories::Billing::CardRepository.new
    batch = cards.create_batch(relay_point_id: @awa.id, quantity: 3, unit_price_xof: 10_000, valid_until: Date.new(2027, 7, 31),
                               created_by_id: @member.id, at: Time.utc(2026, 11, 13))
    batch.cards.each { cards.activate(card_id: it.id, student_id: create_student.id, school_id: school.id, at: Time.utc(2026, 11, 13)) }
    sign_in_as @member

    get teams_billing_cashbox_path

    assert_select "#cashbox_schools tr", text: /Collège Saint Michel.*3.*3 000 F/m
  end

  test "the card-number field leads to the cancellation page and the header has the two actions" do
    sign_in_as @member

    get teams_billing_cashbox_path

    assert_select "form[action='#{teams_billing_card_cancellation_path}'][method=get] input[name=serial]"
    assert_select "a[data-turbo-frame=modal][href='#{new_teams_billing_remittance_path}']", text: "Saisir un versement"
    assert_select "a[href='#{teams_billing_relay_points_path}']", text: "Points relais"
  end

  test "without any relay point, the empty state invites to create one" do
    Orm::Billing::ActivationCard.delete_all
    Orm::Billing::CardBatch.delete_all
    Orm::Billing::Remittance.delete_all
    Orm::Billing::RelayPoint.delete_all
    sign_in_as @member

    get teams_billing_cashbox_path

    assert_select "p", text: "Aucun point relais"
    assert_select "a[href='#{new_teams_billing_relay_point_path}']", text: "Créer un point relais"
  end
end

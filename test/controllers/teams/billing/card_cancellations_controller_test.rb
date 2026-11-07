require "test_helper"

# UDR caisse-equipe §3.5 : annuler une carte remise par son numéro ; une carte activée ne s'annule pas.
class Teams::Billing::CardCancellationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    @issued = Orm::Billing::ActivationCard.where(state: "issued").order(:serial).first
    @activated = Orm::Billing::ActivationCard.where(state: "activated").order(:serial).first
  end

  test "a teacher, a student and a school admin receive 403" do
    [ create_teacher, create_student, create_user(role: "school_admin") ].each do |user|
      sign_in_as user
      get teams_billing_card_cancellation_path(serial: @issued.serial)
      assert_response :forbidden
      post teams_billing_card_cancellation_path, params: { serial: @issued.serial, cancellation: { reason: "perdue" } }
      assert_response :forbidden
      sign_out
    end
    assert_equal "issued", @issued.reload.state
  end

  test "an issued card shows its number, relay point, state and the cancellation form" do
    sign_in_as @member

    get teams_billing_card_cancellation_path(serial: @issued.serial)

    assert_response :success
    assert_select "h1", /N° #{@issued.serial.to_s.rjust(6, "0")}/
    assert_select "body", text: /Boutique Awa/
    assert_select "form[action='#{teams_billing_card_cancellation_path}'][method=post]" do
      assert_select "[name='cancellation[reason]'][maxlength='200']"
      assert_select "button[type=submit]", text: "Annuler la carte"
    end
    assert_select "form[data-turbo-confirm*='Le code ne passera plus jamais']"
  end

  test "an activated card has no form, only the refusal text" do
    sign_in_as @member

    get teams_billing_card_cancellation_path(serial: @activated.serial)

    assert_response :success
    assert_select "body", text: /Une carte activée ne s'annule pas\./
    assert_select "form[action='#{teams_billing_card_cancellation_path}'][method=post]", 0
  end

  test "an unknown number says so" do
    sign_in_as @member

    get teams_billing_card_cancellation_path(serial: "99999999")

    assert_response :not_found
    assert_select "body", text: /Aucune carte ne porte ce numéro\./
  end

  test "without a number, the page only offers the lookup field" do
    sign_in_as @member

    get teams_billing_card_cancellation_path

    assert_response :success
    assert_select "form[method=get] input[name=serial]"
  end

  test "a number without digits is unknown" do
    sign_in_as @member

    get teams_billing_card_cancellation_path(serial: "abc")

    assert_response :not_found
  end

  test "the number can be typed as N° 000021, with spaces" do
    sign_in_as @member

    get teams_billing_card_cancellation_path(serial: " N° #{@issued.serial.to_s.rjust(6, "0")} ")

    assert_response :success
    assert_select "form[action='#{teams_billing_card_cancellation_path}'][method=post]"
  end

  test "cancelling with a reason cancels the card and journals author, date and reason" do
    sign_in_as @member

    assert_difference -> { Orm::AuditEvent.where(action: "billing.card_cancelled").count } => 1 do
      post teams_billing_card_cancellation_path, params: { serial: @issued.serial, cancellation: { reason: "perdue" } }
    end

    assert_redirected_to teams_billing_cashbox_path
    assert_equal [ "cancelled", "perdue", @member.id ], @issued.reload.then { [ it.state, it.cancel_reason, it.cancelled_by_id ] }
    event = Orm::AuditEvent.where(action: "billing.card_cancelled").last
    assert_equal @member.id, event.actor_id
    assert_equal "perdue", event.metadata["reason"]
  end

  test "an empty reason is refused and the card stays issued" do
    sign_in_as @member

    post teams_billing_card_cancellation_path, params: { serial: @issued.serial, cancellation: { reason: "" } }

    assert_response :unprocessable_content
    assert_equal "issued", @issued.reload.state
  end

  test "cancelling an unknown number is a 404" do
    sign_in_as @member

    post teams_billing_card_cancellation_path, params: { serial: "99999", cancellation: { reason: "perdue" } }

    assert_response :not_found
  end

  test "an activated card cannot be cancelled" do
    sign_in_as @member

    post teams_billing_card_cancellation_path, params: { serial: @activated.serial, cancellation: { reason: "perdue" } }

    assert_response :unprocessable_content
    assert_select "body", text: /Une carte activée ne s'annule pas\./
    assert_equal "activated", @activated.reload.state
  end

  test "annuler une carte remise sort une carte de la circulation, sans toucher à ce que le point relais doit" do
    sign_in_as @member
    awa = Orm::Billing::RelayPoint.find_by!(name: "Boutique Awa")
    line = -> { Queries::Billing::CashboxQuery.new.call(at: Time.utc(2026, 11, 13, 12)).relays.find { it.id == awa.id } }
    before = line.call

    post teams_billing_card_cancellation_path, params: { serial: @issued.serial, cancellation: { reason: "perdue" } }

    after = line.call
    assert_equal [ 15, 10_000 ], [ before.in_circulation, before.due_xof ]
    assert_equal [ 14, 10_000, 3 ], [ after.in_circulation, after.due_xof, after.cancelled_count ]
  end
end

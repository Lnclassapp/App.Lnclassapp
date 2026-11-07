require "test_helper"

# UDR caisse-equipe §3.6 : saisir un versement dans la modale, caisse rechargée en Turbo Stream.
class Teams::Billing::RemittancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    @awa = Orm::Billing::RelayPoint.find_by!(name: "Boutique Awa")
  end

  def params(**attributes) = { remittance: { relay_point_id: @awa.id, amount_xof: "5000", reference: "WAVE-5" }.merge(attributes) }

  test "a teacher, a student and a school admin receive 403" do
    [ create_teacher, create_student, create_user(role: "school_admin") ].each do |user|
      sign_in_as user
      get new_teams_billing_remittance_path
      assert_response :forbidden
      post teams_billing_remittances_path, params: params
      assert_response :forbidden
      sign_out
    end
    assert_equal 2, Orm::Billing::Remittance.count
  end

  test "the modal form offers the relay points, an amount, a reference and a reason" do
    sign_in_as @member

    get new_teams_billing_remittance_path, headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal form#remittance-form" do
      assert_select "select[name='remittance[relay_point_id]'] option", text: "Boutique Awa"
      assert_select "input[name='remittance[amount_xof]']"
      assert_select "input[name='remittance[received_at]'][type=datetime-local]"
      assert_select "input[name='remittance[reference]'][maxlength='60']"
      assert_select "textarea[name='remittance[reason]'], input[name='remittance[reason]']"
    end
  end

  test "a valid remittance is written, audited, and the cashbox blocks are replaced" do
    sign_in_as @member

    assert_difference -> { Orm::Billing::Remittance.count } => 1, -> { Orm::AuditEvent.where(action: "billing.remittance_recorded").count } => 1 do
      post teams_billing_remittances_path, params: params, as: :turbo_stream
    end

    assert_response :success
    assert_match "Versement enregistré", response.body
    assert_select "turbo-stream[action=replace][target=cashbox_relays]"
    assert_select "turbo-stream[action=replace][target=cashbox_week]"
    assert_select "turbo-stream[action=update][target=modal]"
    last = Orm::Billing::Remittance.order(:id).last
    assert_equal [ 5_000, @member.id ], [ last.amount_xof, last.recorded_by_id ]
  end

  test "without Turbo the form falls back to a redirect to the cashbox" do
    sign_in_as @member

    post teams_billing_remittances_path, params: params

    assert_redirected_to teams_billing_cashbox_path
  end

  test "a negative amount without a reason is refused in the modal, with the reason, and writes nothing" do
    sign_in_as @member

    assert_no_difference -> { Orm::Billing::Remittance.count } do
      post teams_billing_remittances_path, params: params(amount_xof: "-10000"), headers: { "Turbo-Frame" => "modal" }
    end

    assert_response :unprocessable_content
    assert_select "turbo-frame#modal form#remittance-form [role=alert], turbo-frame#modal form#remittance-form [id$=_error]"
  end

  test "a negative amount with a reason brings the total back and both lines stay" do
    sign_in_as @member
    post teams_billing_remittances_path, params: params(amount_xof: "10000"), as: :turbo_stream
    post teams_billing_remittances_path, params: params(amount_xof: "-10000", reason: "saisi par erreur"), as: :turbo_stream

    assert_response :success
    assert_equal [ 10_000, -10_000 ], Orm::Billing::Remittance.order(:id).last(2).map(&:amount_xof)
    assert_equal 20_000, Orm::Billing::Remittance.where(relay_point_id: @awa.id).sum(:amount_xof)
  end

  test "an unknown relay point is refused" do
    sign_in_as @member

    post teams_billing_remittances_path, params: params(relay_point_id: 0)

    assert_response :unprocessable_content
  end
end

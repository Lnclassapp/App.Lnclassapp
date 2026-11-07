require "test_helper"

# UDR caisse-equipe §3.2 et §3.3, PRD §4 « Points relais et lots » : l'équipe crée et modifie les points relais et leurs écoles.
class Teams::Billing::RelayPointsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    @awa = Orm::Billing::RelayPoint.find_by!(name: "Boutique Awa")
    @school = create_school(name: "Collège Saint Michel")
    @other_school = create_school(name: "Lycée Moderne")
  end

  def params(**overrides)
    { relay_point: { name: "Boutique Kouassi", location: "Gare routière", phone: "0501020304", active: "1",
                     school_ids: [ "", @school.id.to_s, @other_school.id.to_s ] }.merge(overrides) }
  end

  test "un élève, un enseignant et la direction reçoivent 403 partout" do
    [ create_student, create_teacher, create_user(role: "school_admin") ].each do |user|
      sign_in_as user
      get teams_billing_relay_points_path
      assert_response :forbidden
      get new_teams_billing_relay_point_path
      assert_response :forbidden
      post teams_billing_relay_points_path, params: params
      assert_response :forbidden
      get teams_billing_relay_point_path(@awa.public_id)
      assert_response :forbidden
      get edit_teams_billing_relay_point_path(@awa.public_id)
      assert_response :forbidden
      patch teams_billing_relay_point_path(@awa.public_id), params: params
      assert_response :forbidden
      sign_out
    end
    assert_nil Orm::Billing::RelayPoint.find_by(name: "Boutique Kouassi")
  end

  test "la liste montre les points relais par nom, avec leurs écoles et un état" do
    Orm::Billing::RelayPointSchool.create!(relay_point: @awa, school: @school)
    sign_in_as @member

    get teams_billing_relay_points_path

    assert_response :success
    assert_select "h1", "Points relais"
    assert_select "a[data-turbo-frame=modal][href='#{new_teams_billing_relay_point_path}']", text: "Nouveau point relais"
    assert_select "tbody#relay_points tr", 1
    assert_select "tbody#relay_points tr td", text: "Boutique Awa"
    assert_select "tbody#relay_points tr a[href='#{teams_billing_relay_point_path(@awa.public_id)}']"
    assert_select "tbody#relay_points tr a[data-turbo-frame=modal][href='#{edit_teams_billing_relay_point_path(@awa.public_id)}']"
  end

  test "sans point relais : l'état vide propose d'en créer un" do
    Orm::Billing::Remittance.delete_all
    Orm::Billing::ActivationCard.delete_all
    Orm::Billing::CardBatch.delete_all
    Orm::Billing::RelayPoint.delete_all
    sign_in_as @member

    get teams_billing_relay_points_path

    assert_select "p", text: "Aucun point relais"
    assert_select "tbody#relay_points tr", 0
  end

  test "le formulaire de création s'ouvre dans la modale, avec les écoles à cocher" do
    sign_in_as @member

    get new_teams_billing_relay_point_path, headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal dialog form#relay-point-form" do
      assert_select "input[name='relay_point[name]'][maxlength='80']"
      assert_select "input[name='relay_point[location]'][maxlength='120']"
      assert_select "input[name='relay_point[phone]']"
      assert_select "input[type=checkbox][name='relay_point[school_ids][]'][value='#{@school.id}']"
    end
  end

  test "créer « Boutique Kouassi » rattachée à deux écoles : elle apparaît avec ses écoles, la création est journalisée" do
    sign_in_as @member

    assert_difference -> { Orm::Billing::RelayPoint.count } => 1, -> { Orm::AuditEvent.where(action: "billing.relay_point_saved").count } => 1 do
      post teams_billing_relay_points_path, params: params
    end

    created = Orm::Billing::RelayPoint.find_by!(name: "Boutique Kouassi")
    assert_redirected_to teams_billing_relay_point_path(created.public_id)
    assert_equal "Point relais « Boutique Kouassi » créé.", flash[:notice]
    assert_equal "05 01 02 03 04", created.phone
    assert_equal [ @school.id, @other_school.id ].sort, created.relay_point_schools.pluck(:school_id).sort
    follow_redirect!
    assert_select "h1", "Boutique Kouassi"
    assert_select "span", text: "Collège Saint Michel"
    assert_select "span", text: "Lycée Moderne"
    event = Orm::AuditEvent.order(:id).last
    assert_equal [ @member.id, "created" ], [ event.actor_id, event.metadata["change"] ]
  end

  test "une saisie invalide est re-rendue en 422 avec ses erreurs" do
    sign_in_as @member

    assert_no_difference -> { Orm::Billing::RelayPoint.count } do
      post teams_billing_relay_points_path, params: params(name: " ", phone: "12")
    end

    assert_response :unprocessable_content
    assert_select "#relay_point_name_error", "Indiquez le nom du point relais."
    assert_select "#relay_point_phone_error"
    assert_select "input[name='relay_point[location]'][value='Gare routière']"
  end

  test "modifier un point relais remplace ses écoles et peut le désactiver" do
    Orm::Billing::RelayPointSchool.create!(relay_point: @awa, school: @school)
    sign_in_as @member

    get edit_teams_billing_relay_point_path(@awa.public_id), headers: { "Turbo-Frame" => "modal" }
    assert_select "input[type=checkbox][name='relay_point[school_ids][]'][value='#{@school.id}'][checked]"

    patch teams_billing_relay_point_path(@awa.public_id), params: params(name: "Boutique Awa 2", active: "0", school_ids: [ "", @other_school.id.to_s ])

    assert_redirected_to teams_billing_relay_point_path(@awa.public_id)
    assert_equal "Point relais « Boutique Awa 2 » modifié.", flash[:notice]
    @awa.reload
    assert_equal [ "Boutique Awa 2", false ], [ @awa.name, @awa.active ]
    assert_equal [ @other_school.id ], @awa.relay_point_schools.pluck(:school_id)
  end

  test "un point relais inconnu est introuvable" do
    sign_in_as @member

    get teams_billing_relay_point_path("Inconnu")
    assert_response :not_found
    get edit_teams_billing_relay_point_path("Inconnu")
    assert_response :not_found
    patch teams_billing_relay_point_path("Inconnu"), params: params
    assert_response :not_found
  end

  test "la fiche montre le point relais et ses lots avec « Imprimer », ou « Aucun lot de cartes »" do
    sign_in_as @member

    get teams_billing_relay_point_path(@awa.public_id)

    assert_response :success
    assert_select "h1", "Boutique Awa"
    assert_select "a[href='tel:07 00 00 00 00']"
    assert_select "a[data-turbo-frame=modal][href='#{new_teams_billing_relay_point_card_batch_path(@awa.public_id)}']", text: "Nouveau lot de cartes"
    assert_select "tbody#card_batches tr", 1
    assert_select "tbody#card_batches a[href='#{teams_billing_card_batch_sheet_path('AwaBatch000001')}']", text: /Imprimer/

    other = Orm::Billing::RelayPoint.create!(name: "Autre", location: "Ici", phone: "07 11 11 11 11")
    get teams_billing_relay_point_path(other.public_id)
    assert_select "p", text: "Aucun lot de cartes"
  end
end

require "test_helper"

# UDR abonnement-eleve §3: Mon abonnement, une seule page pour l'invitation (gratuit, bloqué), la saisie du code et le reçu.
class Billing::SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 11, 9, 8)
    @school = create_school
    @student = create_student(classroom: create_classroom(school: @school))
    @relay_point = Orm::Billing::RelayPoint.find_by!(name: "Boutique Awa")
  end

  def serve(school: @school) = Orm::Billing::RelayPointSchool.create!(relay_point: @relay_point, school:)

  test "un enseignant, la direction et l'équipe reçoivent 403" do
    [ create_teacher, create_user(role: "school_admin"), create_team_member ].each do |user|
      sign_in_as user
      get billing_subscription_path
      assert_response :forbidden
      sign_out
    end
  end

  test "un visiteur est renvoyé à la connexion" do
    get billing_subscription_path

    assert_redirected_to new_session_path
  end

  test "pendant la période gratuite : les jours restants, le point relais de l'école et la saisie du code" do
    serve
    travel_to Time.utc(2026, 11, 10, 8)
    sign_in_as @student

    get billing_subscription_path

    assert_response :success
    assert_select "h1", "Mon abonnement"
    assert_select "h2", "Il te reste 6 jours gratuits"
    assert_select "li", text: /Boutique Awa/ do
      assert_select "a[href='tel:07 00 00 00 00']"
    end
    assert_select "li", text: /Près du marché/
    assert_select "form#activation-form[action='#{billing_activation_path}']" do
      assert_select "input[name=code][maxlength='20'][autocapitalize=characters][placeholder='XXXX-XXXX-XXXX']"
      assert_select "button[type=submit]", "Activer mon abonnement"
    end
  end

  test "bloqué : la période gratuite est terminée, le point relais est nommé" do
    serve
    travel_to Time.utc(2026, 11, 20, 8)
    sign_in_as @student

    get billing_subscription_path

    assert_select "h2", "Ta période gratuite est terminée"
    assert_select "li", text: /Boutique Awa/
    assert_select "form#activation-form"
  end

  test "un point relais d'une autre école ou désactivé n'est pas montré ; l'état vide donne le WhatsApp de l'équipe" do
    serve(school: create_school)
    sign_in_as @student

    get billing_subscription_path

    assert_select "li", text: /Boutique Awa/, count: 0
    assert_select "p", "Écris-nous pour trouver un point relais"
    assert_select "a[href='https://wa.me/2250584258085']", text: /Écrire sur WhatsApp/
    assert_select "body", text: /05[[:space:]]84[[:space:]]25[[:space:]]80[[:space:]]85/
    assert_includes response.body, "05\u00A084\u00A025\u00A080\u00A085"

    serve
    @relay_point.update!(active: false)
    get billing_subscription_path
    assert_select "li", text: /Boutique Awa/, count: 0
  end

  test "un élève sans école voit le WhatsApp de l'équipe" do
    sign_in_as create_student

    get billing_subscription_path

    assert_select "a[href='https://wa.me/2250584258085']"
  end

  test "abonné : le reçu, sans formulaire ni point relais" do
    serve
    card = Orm::Billing::ActivationCard.find_by!(state: "issued")
    Repositories::Billing::CardRepository.new.activate(card_id: card.id, student_id: @student.id, school_id: @school.id, at: Time.current)
    sign_in_as @student

    get billing_subscription_path

    assert_select "h2", "Ton abonnement est actif"
    assert_select "body", text: /Jusqu'au 31 juillet 2027/
    assert_select "form#activation-form", count: 0
    assert_select "li", text: /Boutique Awa/, count: 0
  end
end

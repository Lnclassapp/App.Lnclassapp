require "test_helper"

# ADR cartes-activation §4.3 et §4.4, PRD §4 « Activation » : le code est normalisé, la carte verrouillée, les essais freinés.
class Billing::ActivationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 11, 9, 8)
    @school = create_school
    @student = create_student(classroom: create_classroom(school: @school))
    @card = Orm::Billing::ActivationCard.where(state: "issued").order(:serial).first
    travel_to Time.utc(2026, 11, 20, 8)
    sign_in_as @student
  end

  def typed(card = @card) = " #{card.code.downcase.scan(/.{4}/).join(' ')} "
  def activate(code) = post(billing_activation_path, params: { code: })
  def access = Queries::Billing::StudentAccessQuery.new.call(student_id: @student.id, at: Time.current)

  test "un code en minuscules avec des espaces abonne l'élève jusqu'au 31 juillet 2027" do
    assert_predicate access, :blocked?

    activate(typed)

    assert_redirected_to billing_subscription_path
    assert_equal "Ton abonnement est actif jusqu'au 31 juillet 2027", flash[:notice]
    @card.reload
    assert_equal [ "activated", @student.id, @school.id, Time.current ], [ @card.state, @card.student_id, @card.school_id, @card.activated_at ]
    assert_equal Date.new(2027, 7, 31), access.subscribed_until
    assert_equal "billing.card_activated", Orm::AuditEvent.order(:id).last.action
  end

  test "l'élève reprend l'exercice qui l'avait bloqué quand le contrat de blocage a rangé son chemin" do
    controller = Billing::ActivationsController.new

    assert_equal "/students/exercises/1", controller.send(:safe_return_path, "/students/exercises/1")
    [ "//evil.example", "/\\evil.example", "https://evil.example", "", nil, 12 ].each { assert_nil controller.send(:safe_return_path, it) }
  end

  test "un élève sans école active quand même ; la carte n'est rattachée à aucune école" do
    sign_out
    loner = create_student
    sign_in_as loner

    activate(typed)

    assert_redirected_to billing_subscription_path
    assert_nil @card.reload.school_id
    assert_equal loner.id, @card.student_id
  end

  test "un autre élève saisissant le même code lit « Cette carte a déjà été utilisée. »" do
    activate(typed)
    sign_out
    other = create_student
    sign_in_as other

    activate(typed)

    assert_response :unprocessable_content
    assert_select "[role=alert]", "Cette carte a déjà été utilisée."
    assert_equal @student.id, @card.reload.student_id
  end

  test "une carte annulée est refusée" do
    @card.update!(state: "cancelled", cancelled_at: Time.current, cancel_reason: "perdue")

    activate(typed)

    assert_response :unprocessable_content
    assert_select "[role=alert]", "Cette carte n'est plus valable. Rapporte-la au point relais."
  end

  test "un code inconnu est refusé, rien ne change, la saisie reste dans le champ" do
    activate("zzzz zzzz zzzz")

    assert_response :unprocessable_content
    assert_select "[role=alert]", "Ce code n'existe pas. Vérifie-le sur ta carte."
    assert_select "input[name=code][value='zzzz zzzz zzzz'][aria-invalid=true]"
    assert_equal 15, Orm::Billing::ActivationCard.where(state: "issued").count
  end

  test "un code absent ou qui n'est pas un texte est refusé comme un code inconnu" do
    [ {}, { code: [ "a" ] }, { code: { a: "b" } } ].each do |params|
      post billing_activation_path, params: params

      assert_response :unprocessable_content
      assert_select "[role=alert]", "Ce code n'existe pas. Vérifie-le sur ta carte."
    end
  end

  test "un élève déjà abonné qui saisit une 2e carte la laisse disponible pour un camarade" do
    activate(typed)
    second = Orm::Billing::ActivationCard.where(state: "issued").order(:serial).first

    activate(typed(second))

    assert_response :unprocessable_content
    assert_select "[role=alert]", "Tu es déjà abonné jusqu'au 31 juillet 2027. Garde cette carte pour un camarade."
    assert_equal "issued", second.reload.state
  end

  test "le 6e essai en 10 minutes est refusé sans être évalué, même avec un code juste" do
    5.times { activate("zzzz zzzz zzzz") }
    assert_response :unprocessable_content

    activate(typed)

    assert_response :too_many_requests
    assert_select "[role=alert]", "Trop de tentatives. Réessaie dans quelques minutes."
    assert_equal "issued", @card.reload.state
  end

  test "un enseignant, la direction et l'équipe reçoivent 403 sans rien activer" do
    sign_out
    [ create_teacher, create_user(role: "school_admin"), create_team_member ].each do |user|
      sign_in_as user
      activate(typed)
      assert_response :forbidden
      sign_out
    end
    assert_equal "issued", @card.reload.state
  end

  test "une carte activée entre-temps (course) rend « déjà abonné jusqu'au … » avec la date" do
    other = Orm::Billing::ActivationCard.where(state: "issued").where.not(id: @card.id).order(:serial).first
    Repositories::Billing::CardRepository.new.activate(card_id: other.id, student_id: @student.id, school_id: nil, at: Time.current)
    # Le use case a lu « pas encore abonné » : le dépôt, lui, trouve l'abonnement posé entre-temps.
    reads = 0
    stub_any_instance(Repositories::Billing::CardRepository, :subscribed_until, ->(**) { (reads += 1) == 1 ? nil : Date.new(2027, 7, 31) }) do
      activate(typed)
    end
    assert_equal 2, reads

    assert_response :unprocessable_content
    assert_select "[role=alert]", "Tu es déjà abonné jusqu'au 31 juillet 2027. Garde cette carte pour un camarade."
    assert_equal "issued", @card.reload.state
  end

  test "un échec sans erreur nommée reçoit le message de son code" do
    stub_any_instance(UseCases::Billing::ActivateCard, :call, ->(**) { Shared::Result.failure(:conflict) }) do
      activate(typed)
    end

    assert_response :unprocessable_content
    assert_select "[role=alert]", I18n.t("errors.codes.conflict")
  end

  test "le freinage d'un élève ne touche pas un autre élève" do
    5.times { activate("zzzz zzzz zzzz") }
    activate(typed)
    assert_response :too_many_requests
    sign_out
    other = create_student
    sign_in_as other

    activate(typed)

    assert_redirected_to billing_subscription_path
    assert_equal other.id, @card.reload.student_id
  end
end

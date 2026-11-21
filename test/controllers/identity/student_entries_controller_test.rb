require "test_helper"

# Chantier entree-eleve-unifiee (PRD §4, ADR-XXXX-entree-eleve-revele-un-numero-inscrit, UDR-XXXX-entree-eleve-unique) :
# « Je suis élève » ouvre une seule entrée, numéro et code secret ; inscrit → connecté ; inconnu → confirmer le code, puis
# l'inscription sans retaper ni l'un ni l'autre ; code faux → « Code secret incorrect » et « Code secret oublié ? ».
class Identity::StudentEntriesControllerTest < ActionDispatch::IntegrationTest
  PAGE = "identity.student_entries.new".freeze

  setup do
    @drena = create_drena(name: "Agnéby-Tiassa")
    @school = create_school(drena: @drena, name: "Collège Notre-Dame de la Paix")
    @level = create_level(name: "6ème")
    @classroom = create_classroom(school: @school, level: @level, name: "6e 1")
  end

  def enter(contact:, pin:, **extra) = post(student_entries_path, params: { student_entry: { contact:, pin:, **extra } })
  def confirm(pin) = post(student_entries_path, params: { student_entry: { pin_confirmation: pin } })

  def finish_registration(**extra)
    post student_registrations_path, params: {
      entry_mode: 1,
      student_registration: { last_name: "KOUAME", first_name: "Yao", gender: "male", drena_public_id: @drena.public_id,
                              school_public_id: @school.public_id, level_slug: @level.slug, classroom_public_id: @classroom.public_id,
                              **extra }
    }
  end

  test "CA-1 : l'accueil mène « Je suis élève » droit à l'entrée, sans modale" do
    get root_path

    assert_select "a#role-entry-student-entry[href=?]", new_student_entry_path, text: "Je suis élève"
    assert_select "dialog#role-modal-student-entry", 0
  end

  test "CA-1 : l'entrée montre le numéro et le code secret, rien d'autre" do
    get new_student_entry_path

    assert_response :success
    assert_select "h1", text: "Je suis élève"
    assert_select "form#student-entry-form[action=?]", student_entries_path do
      assert_select "input[type=tel][name='student_entry[contact]']"
      assert_select "input[type=password][name='student_entry[pin]'][maxlength='4']"
    end
    assert_select "#student-entry-forgot-pin", 0
  end

  test "CA-2 : un élève inscrit et son code arrivent sur l'accueil élève" do
    create_student(contact: "0701020304", classroom: @classroom)

    enter(contact: "07 01 02 03 04", pin: "2468")

    assert_redirected_to student_home_path
  end

  test "CA-3 : un enseignant inscrit est connecté par l'entrée élève" do
    create_teacher(contact: "0501020304")

    enter(contact: "0501020304", pin: "2468")

    assert_redirected_to teacher_home_path
    follow_redirect!
    assert_no_match "Je suis élève", response.body
  end

  test "CA-4 : un code faux dit « Code secret incorrect » et propose « Code secret oublié ? », sans session" do
    create_student(contact: "0701020304", classroom: @classroom)

    enter(contact: "0701020304", pin: "1111")

    assert_response :unprocessable_entity
    assert_select "#student_entry_pin_error", text: "Code secret incorrect."
    assert_select "a#student-entry-forgot-pin[href=?]", new_identity_pin_reset_path, text: "Code secret oublié ?"
    assert_equal 1, Orm::LoginAttempt.where(contact: "0701020304", succeeded: false).count
    get student_home_path
    assert_response :redirect
  end

  test "CA-5 : un numéro inconnu confirme son code puis s'inscrit sans retaper numéro ni code" do
    enter(contact: "0101020304", pin: "1357")
    assert_redirected_to new_student_entry_path
    follow_redirect!
    assert_select "h1", text: "Nouveau sur Lnclass"
    assert_select "#student-entry-number", text: /01 01 02 03 04/
    assert_select "a#student-entry-fix-number", text: "Ce n'est pas mon numéro"
    # Ce lien efface l'entrée : Turbo ne doit pas le précharger au survol.
    assert_select "a#student-entry-fix-number[data-turbo-prefetch=false]"
    assert_no_match "1357", response.body

    confirm("1357")
    assert_redirected_to new_student_registration_path
    follow_redirect!
    assert_select "#signup-entry-number", text: /01 01 02 03 04/
    assert_select "input[name='student_registration[contact]']", 0
    assert_select "input[name='student_registration[pin]']", 0
    assert_select "#signup-step-counter", text: "Étape 1 sur 2"
    assert_no_match "1357", response.body

    finish_registration
    assert_redirected_to student_home_path
    user = Orm::User.find_by!(contact: "0101020304")
    assert_equal "student", user.role
    assert user.authenticate_pin("1357")
    assert Orm::ClassroomStudent.exists?(student: user, classroom_id: @classroom.id)
  end

  test "CA-6 : une confirmation différente est refusée, l'écran reste" do
    enter(contact: "0101020304", pin: "1357")

    confirm("7531")

    assert_response :unprocessable_entity
    assert_select "#student_entry_pin_confirmation_error", text: "Les deux codes secrets ne sont pas identiques."
    get new_student_registration_path
    assert_select "#signup-entry-number", 0
  end

  test "« Ce n'est pas mon numéro » oublie l'entrée et remet le numéro dans le champ" do
    enter(contact: "0101020304", pin: "1357")

    get new_student_entry_path(fresh: 1)

    assert_select "form#student-entry-form input[name='student_entry[contact]'][value='0101020304']"
    assert_select "form#student-entry-confirm-form", 0
  end

  test "CA-7 : un numéro pris entre l'entrée et l'inscription : refus, aucun second compte" do
    enter(contact: "0101020304", pin: "1357")
    confirm("1357")
    create_student(contact: "0101020304")

    assert_no_difference -> { Orm::User.count } do
      finish_registration
    end
    assert_response :unprocessable_entity
    assert_select "#signup-entry-number-error", text: "Ce numéro est déjà utilisé."
  end

  test "CA-8 : par le lien de classe, l'entrée montre la classe ; nouveau, il s'inscrit dans cette classe à l'étape « Toi »" do
    token = @classroom.reload.link_token

    get join_classroom_path(token)
    assert_select "#student-entry-classroom", text: /6e 1/
    assert_select "form#student-entry-form input[type=hidden][name='student_entry[link_token]'][value=?]", token

    enter(contact: "0101020304", pin: "1357", link_token: token)
    confirm("1357")
    assert_redirected_to join_classroom_path(token)
    follow_redirect!
    assert_select "#student-signup[data-classroom--signup-steps-start-value='2']"
    assert_select "#signup-classroom-recap", text: /6e 1/
    assert_select "#signup-step-counter", text: "Étape 2 sur 2"

    post student_registrations_path, params: { entry_mode: 1, student_registration: { last_name: "KOUAME", first_name: "Yao",
                                                                                      gender: "male", link_token: token } }
    assert_redirected_to student_home_path
    user = Orm::User.find_by!(contact: "0101020304")
    assert Orm::ClassroomStudent.exists?(student: user, classroom_id: @classroom.id)
  end

  test "CA-9 : un élève inscrit sans classe, entré par le lien, revient sur la page du lien" do
    create_student(contact: "0701020304")
    token = @classroom.reload.link_token

    enter(contact: "0701020304", pin: "2468", link_token: token)

    assert_redirected_to join_classroom_path(token)
    follow_redirect!
    assert_response :success
    get student_home_path
    assert_response :success
  end

  test "CA-10 : une classe de 60 nouveaux élèves (deux envois chacun) passe l'entrée depuis une adresse ; le 121e envoi reçoit 429" do
    120.times do |i|
      enter(contact: format("01%08d", i), pin: "1357")
      assert_response :see_other, "entry #{i + 1} was refused (#{response.status})"
    end

    enter(contact: "0199999999", pin: "1357")

    assert_response :too_many_requests
    assert_select "#student-entry-alert[role=alert]", text: I18n.t("errors.codes.rate_limited")
  end

  test "CA-10 : 10 codes faux sur 10 numéros inscrits depuis une adresse passent en 422 ; le 11e, même avec le bon code, reçoit 429" do
    11.times { |i| create_student(contact: format("07%08d", i), classroom: @classroom) }
    10.times do |i|
      enter(contact: format("07%08d", i), pin: "1111")
      assert_response :unprocessable_entity, "wrong code #{i + 1} was not a 422 (#{response.status})"
    end

    enter(contact: format("07%08d", 10), pin: "2468")

    assert_response :too_many_requests
    assert_select "#student-entry-alert[role=alert]", text: I18n.t("errors.codes.rate_limited")
    get student_home_path
    assert_response :redirect
    assert_not_equal student_home_path, URI(response.location).path
  end

  test "CA-10 : un numéro inconnu n'est pas un code faux : 11 numéros inconnus ne déclenchent pas ce compteur" do
    11.times do |i|
      enter(contact: format("01%08d", i), pin: "1357")
      assert_response :see_other, "unknown number #{i + 1} was refused (#{response.status})"
    end
  end

  test "CA-10 : après l'entrée, 12 inscriptions par la liste depuis une adresse en une minute passent (pas 5 par minute)" do
    @classroom.update!(max_students: 60)
    freeze_time do
      12.times do |i|
        enter(contact: format("01%08d", i), pin: "1357")
        confirm("1357")
        finish_registration
        assert_redirected_to student_home_path, "registration #{i + 1} was refused (#{response.status})"
        sign_out
      end
    end
  end

  test "un numéro verrouillé reçoit 429 et l'heure de déverrouillage" do
    student = create_student(contact: "0701020304", classroom: @classroom)
    5.times { create_login_attempt(contact: student.contact) }

    enter(contact: "0701020304", pin: "2468")

    assert_response :too_many_requests
    assert_select "[role=alert]", text: /Réessayez à/
    assert_equal 0, Orm::Session.count
  end

  test "dans l'app élèves, le compte d'un enseignant est renvoyé à son app, sans session" do
    create_teacher(contact: "0501020304")
    agent = "Mozilla/5.0 (Linux; Android 13; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 " \
            "Hotwire Native Android; LnclassStudentAndroid/1.0"

    post student_entries_path, params: { student_entry: { contact: "0501020304", pin: "2468" } }, headers: { "User-Agent" => agent }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: I18n.t("identity.student_entries.create.wrong_app")
    assert_equal 0, Orm::Session.count
    assert_empty cookies[:session_token].to_s
  end

  test "CA-11 : une entrée de plus de 30 minutes est oubliée ; le formulaire du mode entrée renvoie à l'entrée sans rien créer" do
    enter(contact: "0101020304", pin: "1357")
    confirm("1357")

    travel 29.minutes do
      get new_student_registration_path
      assert_select "#signup-entry-number"
    end

    travel 31.minutes do
      get new_student_registration_path
      assert_select "#signup-entry-number", 0

      assert_no_difference -> { Orm::User.count } do
        finish_registration
      end
      assert_redirected_to new_student_entry_path
    end
  end

  test "une confirmation sans entrée (expirée) renvoie à l'entrée" do
    confirm("1357")

    assert_redirected_to new_student_entry_path
  end

  test "un numéro hors format ou un code trop court ne cherche rien" do
    enter(contact: "0901020304", pin: "1357")
    assert_response :unprocessable_entity
    assert_select "#student_entry_contact_error"

    enter(contact: "0101020304", pin: "13")
    assert_select "#student_entry_pin_error", text: "Le code secret compte 4 chiffres."
  end

  test "un compte connecté qui ouvre l'entrée retrouve son accueil" do
    sign_in_as create_student(classroom: @classroom)

    get new_student_entry_path

    assert_redirected_to student_home_path
  end

  test "une entrée confirmée renvoie l'entrée à l'inscription, sans reposer le numéro" do
    enter(contact: "0101020304", pin: "1357")
    confirm("1357")

    get new_student_entry_path

    assert_redirected_to new_student_registration_path
  end

  test "un connecté qui envoie l'entrée retrouve son accueil, sans nouvelle session" do
    sign_in_as create_student(classroom: @classroom)

    enter(contact: "0101020304", pin: "1357")

    assert_redirected_to student_home_path
    assert_not Orm::User.exists?(contact: "0101020304")
  end

  test "un lien de classe inconnu est oublié : l'entrée s'ouvre sans bandeau ni jeton" do
    get new_student_entry_path(link: "abcdef012345")

    assert_response :success
    assert_select "#student-entry-classroom", 0
    assert_select "input[name='student_entry[link_token]']", 0
  end

  test "le lien d'une classe ouverte passé à l'entrée en montre le bandeau et garde le jeton" do
    token = @classroom.reload.link_token

    get new_student_entry_path(link: token)

    assert_select "#student-entry-classroom", text: /6e 1/
    assert_select "input[type=hidden][name='student_entry[link_token]'][value=?]", token
  end
end

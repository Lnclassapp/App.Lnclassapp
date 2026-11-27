require "test_helper"

# Chantiers entree-eleve-unifiee (ADR-0141, UDR-0176) et connexion-numero-d-abord (ADR-0148, UDR-0189) :
# « Je suis élève » demande le numéro d'abord ; inscrit → le code, puis connecté ; inconnu → « Nouveau sur Lnclass », le code
# tapé une fois, puis l'inscription sans retaper ni l'un ni l'autre ; code faux → « Code secret incorrect » et « Code secret oublié ? ».
class Identity::StudentEntriesControllerTest < ActionDispatch::IntegrationTest
  PAGE = "identity.student_entries.new".freeze

  setup do
    @drena = create_drena(name: "Agnéby-Tiassa")
    @school = create_school(drena: @drena, name: "Collège Notre-Dame de la Paix")
    @level = create_level(name: "6ème")
    @classroom = create_classroom(school: @school, level: @level, name: "6e 1")
  end

  # Le parcours réel : le numéro seul, puis, s'il est donné, le code seul (numéro gardé en session).
  def enter(contact:, pin: nil, **extra)
    send_number(contact:, **extra)
    send_pin(pin, **extra.slice(:link_token)) if pin && response.status == 303 && response.location.end_with?(new_student_entry_path)
  end

  def send_number(contact:, **extra) = post(student_entries_path, params: { student_entry: { contact:, **extra } })
  def send_pin(pin, **extra) = post(student_entries_path, params: { student_entry: { pin:, **extra } })

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

  test "CA-1 : l'entrée montre le numéro seul, rien d'autre" do
    get new_student_entry_path

    assert_response :success
    assert_select "h1", text: "Je suis élève"
    assert_select "form#student-entry-form[action=?]", student_entries_path do
      assert_select "input[type=tel][name='student_entry[contact]']"
      assert_select "input[name='student_entry[pin]']", 0
    end
    assert_select "#student-entry-forgot-pin", 0
  end

  test "une entrée fraîche sans entrée en session ouvre le champ numéro vide" do
    get new_student_entry_path(fresh: 1)

    assert_response :success
    assert_select "input[name='student_entry[contact]']" do |inputs|
      assert_predicate inputs.first["value"], :blank?
    end
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

  test "numéro d'abord : un numéro inscrit ouvre « Entre ton code secret », numéro affiché, sans nom" do
    create_student(contact: "0701020304", classroom: @classroom, last_name: "KOUAME")

    send_number(contact: "0701020304")
    follow_redirect!

    assert_select "h1", text: "Entre ton code secret"
    assert_select "#student-entry-number", text: /Ton numéro\s*07 01 02 03 04/
    assert_select "form#student-entry-pin-form input[name='student_entry[pin]'][autocomplete=current-password]"
    assert_select "form#student-entry-pin-form input[name='student_entry[contact]']", 0
    assert_select "a#student-entry-fix-number[data-turbo-prefetch=false]", text: "Ce n'est pas mon numéro"
    assert_no_match "KOUAME", response.body
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

  test "CA-1 (pavé) : l'entrée ne porte plus les deux phrases d'explication" do
    get new_student_entry_path

    assert_response :success
    assert_no_match "Ton numéro et ton code secret : on te connecte, ou on crée ton compte.", response.body
    assert_no_match "Pas encore de compte ? Tape ton numéro et choisis un code secret", response.body
    assert_select "#auth-welcome-card", text: /Bienvenue sur Lnclass/
  end

  test "pavé : un numéro inconnu reçoit le pavé « Entre ton code secret », masqué sans JavaScript" do
    send_number(contact: "0101020304")
    follow_redirect!

    assert_select "form#student-entry-confirm-form[data-controller='identity--pin-pad']" do
      assert_select "#student-entry-pin-field input[name='student_entry[pin]'][autocomplete=new-password]"
      assert_select "input[name='student_entry[pin_confirmation]']", 0
      assert_select "#student-entry-pin-pad[hidden]" do
        assert_select "[data-identity--pin-pad-target='box']", 4
        assert_select "#student-entry-keypad button[data-digit]", 10
        assert_select "#student-entry-keypad button[aria-label=?]", "Effacer"
        assert_select "#student-entry-pin-offline[hidden][role=alert][data-identity--pin-pad-target=offline]", text: "Pas de connexion. Réessaie."
      end
      assert_select "#student-entry-confirm-submit:not([disabled])"
    end
    assert_select "#student-entry-pin-pad", text: /Entre ton code secret : 4 chiffres, que tu retiendras\./
    assert_no_match "Retape", response.body
  end

  test "CA-9 : un numéro inconnu tape son code une fois puis s'inscrit sans retaper numéro ni code" do
    send_number(contact: "0101020304")
    assert_redirected_to new_student_entry_path
    follow_redirect!
    assert_select "h1", text: "Nouveau sur Lnclass"
    assert_select "#student-entry-number", text: /01 01 02 03 04/
    assert_select "a#student-entry-fix-number", text: "Ce n'est pas mon numéro"
    # Ce lien efface l'entrée : Turbo ne doit pas le précharger au survol.
    assert_select "a#student-entry-fix-number[data-turbo-prefetch=false]"

    send_pin("1357")
    assert_redirected_to new_student_registration_path
    follow_redirect!
    # CA-7: the number is neither shown nor asked again after the entry.
    assert_select "#signup-entry-number", 0
    assert_select "input[name=entry_mode]"
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

  test "un code mal formé sur « Nouveau sur Lnclass » est refusé, l'écran reste, aucune inscription ouverte" do
    send_number(contact: "0101020304")

    send_pin("13")

    assert_response :unprocessable_entity
    assert_select "h1", text: "Nouveau sur Lnclass"
    assert_select "#student_entry_pin_error", text: "Le code secret compte 4 chiffres."
    get new_student_registration_path
    assert_select "input[name=entry_mode]", 0
  end

  test "CA-10 : un numéro devenu inscrit entre « Nouveau sur Lnclass » et le code : une connexion, jamais un second compte" do
    send_number(contact: "0101020304")
    create_student(contact: "0101020304", classroom: @classroom)

    assert_no_difference -> { Orm::User.count } do
      send_pin("2468")
    end
    assert_redirected_to student_home_path
  end

  test "numéro et code envoyés ensemble (page d'avant) : un numéro inconnu passe droit à l'inscription" do
    post student_entries_path, params: { student_entry: { contact: "0101020304", pin: "1357" } }

    assert_redirected_to new_student_registration_path
  end

  test "l'écran « pas de compte » de /login mène, par « Élève », à « Nouveau sur Lnclass », numéro repris" do
    post session_path, params: { session: { contact: "0101020304" } }

    get new_student_entry_path

    assert_select "h1", text: "Nouveau sur Lnclass"
    assert_select "#student-entry-number", text: /01 01 02 03 04/
    send_pin("1357")
    assert_redirected_to new_student_registration_path
  end

  test "« Ce n'est pas mon numéro » oublie l'entrée et remet le numéro dans le champ" do
    send_number(contact: "0101020304")

    get new_student_entry_path(fresh: 1)

    assert_select "form#student-entry-form input[name='student_entry[contact]'][value='0101020304']"
    assert_select "form#student-entry-confirm-form", 0
  end

  test "CA-7 : un numéro pris entre l'entrée et l'inscription : refus, aucun second compte" do
    enter(contact: "0101020304", pin: "1357")
    create_student(contact: "0101020304")

    assert_no_difference -> { Orm::User.count } do
      finish_registration
    end
    assert_response :unprocessable_entity
    assert_select "#signup-entry-number-error", text: "Ce numéro est déjà utilisé."
    assert_select "#signup-entry-number a#signup-entry-fix-number[href=?]", new_student_entry_path(fresh: 1)
  end

  test "CA-8 : par le lien de classe, l'entrée montre la classe ; nouveau, il s'inscrit dans cette classe à l'étape « Toi »" do
    token = @classroom.reload.link_token

    get join_classroom_path(token)
    assert_select "#student-entry-classroom", text: /6e 1/
    assert_select "form#student-entry-form input[type=hidden][name='student_entry[link_token]'][value=?]", token

    enter(contact: "0101020304", pin: "1357", link_token: token)
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
    60.times do |i|
      enter(contact: format("01%08d", i), pin: "1357")
      assert_response :see_other, "entry #{i + 1} was refused (#{response.status})"
      reset!
    end

    send_number(contact: "0199999999")

    assert_response :too_many_requests
    assert_select "#student-entry-alert[role=alert]", text: I18n.t("errors.codes.rate_limited")
  end

  test "CA-10 : 5 codes faux sur 5 numéros inscrits depuis une adresse passent en 422 ; le 6e, même avec le bon code, reçoit 429" do
    6.times { |i| create_student(contact: format("07%08d", i), classroom: @classroom) }
    5.times do |i|
      enter(contact: format("07%08d", i), pin: "1111")
      assert_response :unprocessable_entity, "wrong code #{i + 1} was not a 422 (#{response.status})"
    end

    enter(contact: format("07%08d", 5), pin: "2468")

    assert_response :too_many_requests
    assert_select "#student-entry-alert[role=alert]", text: I18n.t("errors.codes.rate_limited")
    get student_home_path
    assert_response :redirect
    assert_not_equal student_home_path, URI(response.location).path
  end

  # Revue sécurité du 2026-11-24 (ADR-0050) : 5 codes faux au plus par compte, 5 par minute et par adresse, les deux entrées confondues.
  test "3 codes faux sur /login puis 2 sur /student verrouillent le même compte" do
    student = create_student(contact: "0701020304", classroom: @classroom)
    3.times { post session_path, params: { session: { contact: student.contact, pin: "1111" } } }
    2.times do
      travel 61.seconds
      enter(contact: student.contact, pin: "1111")
    end
    travel 61.seconds

    enter(contact: student.contact, pin: "2468")

    assert_response :too_many_requests
    assert_select "[role=alert]", text: I18n.t("errors.locked.until_recovery")
    assert_equal 0, Orm::Session.count
  end

  test "6 envois sur /login puis /student depuis une adresse : le plafond de codes faux est commun" do
    11.times { |i| create_student(contact: format("07%08d", i), classroom: @classroom) }
    6.times { |i| post session_path, params: { session: { contact: format("07%08d", i), pin: "1111" } } }
    assert_response :too_many_requests

    enter(contact: format("07%08d", 6), pin: "2468")

    assert_response :too_many_requests
  end

  test "5 codes faux sur /student puis /login depuis une adresse : /login est refusé en 429, même avec le bon code" do
    6.times { |i| create_student(contact: format("07%08d", i), classroom: @classroom) }
    5.times { |i| enter(contact: format("07%08d", i), pin: "1111") }

    post session_path, params: { session: { contact: format("07%08d", 5), pin: "2468" } }

    assert_response :too_many_requests
  end

  test "CA-10 : un numéro inconnu n'est pas un code faux : 11 numéros inconnus ne déclenchent pas ce compteur" do
    11.times do |i|
      enter(contact: format("01%08d", i), pin: "1357")
      assert_response :see_other, "unknown number #{i + 1} was refused (#{response.status})"
      reset!
    end
  end

  test "CA-10 : après l'entrée, 12 inscriptions par la liste depuis une adresse en une minute passent (pas 5 par minute)" do
    @classroom.update!(max_students: 60)
    freeze_time do
      12.times do |i|
        enter(contact: format("01%08d", i), pin: "1357")
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
    assert_select "[role=alert]", text: I18n.t("errors.locked.until_recovery")
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

    travel 29.minutes do
      get new_student_registration_path
      assert_select "input[name=entry_mode]"
    end

    travel 31.minutes do
      get new_student_registration_path
      assert_select "input[name=entry_mode]", 0

      assert_no_difference -> { Orm::User.count } do
        finish_registration
      end
      assert_redirected_to new_student_entry_path
    end
  end

  test "un numéro inscrit gardé plus de 30 minutes : l'écran du numéro revient, et un code envoyé renvoie à l'entrée sans rien créer" do
    student = create_student
    send_number(contact: student.contact)

    travel 31.minutes do
      get new_student_entry_path
      assert_select "input[name='student_entry[contact]']"
      assert_select "input[name='student_entry[pin]']", 0

      assert_no_difference -> { Orm::Session.count } do
        send_pin("2468")
      end
      assert_redirected_to new_student_entry_path
      assert_equal I18n.t("identity.student_entries.create.expired"), flash[:alert]
    end
  end

  test "un code sans entrée (expirée) renvoie à l'entrée" do
    send_pin("1357")

    assert_redirected_to new_student_entry_path
  end

  test "un numéro hors format ou un code trop court ne cherche rien" do
    enter(contact: "0901020304", pin: "1357")
    assert_response :unprocessable_entity
    assert_select "#student_entry_contact_error"

    post student_entries_path, params: { student_entry: { contact: "0101020304", pin: "13" } }
    assert_select "#student-entry-alert[role=alert]", text: /Le code secret compte 4 chiffres\./
  end

  test "un compte connecté qui ouvre l'entrée retrouve son accueil" do
    sign_in_as create_student(classroom: @classroom)

    get new_student_entry_path

    assert_redirected_to student_home_path
  end

  test "une entrée confirmée renvoie l'entrée à l'inscription, sans reposer le numéro" do
    enter(contact: "0101020304", pin: "1357")

    get new_student_entry_path

    assert_redirected_to new_student_registration_path
  end

  test "un connecté qui envoie l'entrée retrouve son accueil, sans nouvelle session" do
    sign_in_as create_student(classroom: @classroom)

    post student_entries_path, params: { student_entry: { contact: "0101020304", pin: "1357" } }

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

require "test_helper"

# Chantier mvp-teacher-student, lot F (chantier page-d-accueil-photo, UDR-0059) : la page d'accueil publique est une photo,
# une feuille qui porte « Tu comprends chap chap », la pastille « Même sans internet » et deux entrées de rôle (modales,
# UDR-0012 §2) ; ni en-tête, ni pied de page, ni section qui oblige à défiler (CA-A1, CA-A3).
# CA-A2 : « Espace établissement » (lien et fenêtre) n'existe que drapeau `school_space_enabled` allumé.
class HomepageControllerTest < ActionDispatch::IntegrationTest
  # UDR-0058 §3 : the subjects of the student grid, EDHC (1st cycle) and Philosophie (2nd cycle) both listed.
  # ADR-0084 §4.1 : le User-Agent de la coque Android élèves ; un navigateur ; une autre coque Hotwire Native, sans jeton.
  ANDROID_APP = "Mozilla/5.0 (Linux; Android 13; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 " \
                "Hotwire Native Android; LnclassStudentAndroid/1.0".freeze
  # ADR-0086 §4.1 : la coque Android enseignants, « Lnclass Teacher ».
  TEACHER_APP = ANDROID_APP.sub("LnclassStudentAndroid", "LnclassTeacherAndroid").freeze
  BROWSER = "Mozilla/5.0 (Linux; Android 13; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36".freeze
  OTHER_SHELL = "#{BROWSER} Hotwire Native Android".freeze
  SUBJECTS = [ "Mathématiques", "Physique-Chimie", "SVT", "Français", "Histoire-Géographie", "EDHC", "Philosophie" ].freeze
  INFORMAL = /\b(tu|tes|ton|toi)\b/i

  test "the homepage is served at the root" do
    get root_url

    assert_response :success
  end

  # CA-A1 : la photo, « Tu comprends chap chap » en gras, la vague jaune, la pastille et les deux entrées.
  test "CA-A1: the photo, the bold slogan underlined by the yellow wave, the pill and the two entries" do
    get root_url

    assert_select "h1", 1
    assert_select "h1.font-extrabold", text: /Tu comprends/
    assert_select "h1", text: /chap chap/
    assert_select "h1 svg[aria-hidden='true'].text-gold path"
    assert_select "main img[src*='student-portrait']", 1
    assert_select "main [role='note']", text: "Même sans internet"
    assert_select "main button[aria-haspopup='dialog']", text: "Je suis élève"
    assert_select "main button[aria-haspopup='dialog']", text: "Enseignant(e)"
    assert_select "main button[aria-haspopup='dialog'].ui-button-lg.w-full", 2
  end

  test "CA-A3: no header, no footer, no section to scroll to: the page is a single screen" do
    get root_url

    assert_select "header, footer, nav", 0
    assert_select "section", 0
    assert_select "a[href^='#']", 0
    # « Se connecter » n'existe que dans les deux fenêtres de rôle : la page n'a pas de lien propre.
    assert_select "a[href='#{new_session_path}']", 2
    assert_select "dialog a[href='#{new_session_path}']", 2
  end

  test "the visitor sees the student and teacher entries, once each" do
    get root_url

    assert_select "button[aria-haspopup='dialog']", text: "Je suis élève", count: 1
    assert_select "button[aria-haspopup='dialog']", text: "Enseignant(e)", count: 1
    assert_select "a, button", text: "Commencer", count: 0
    assert_select "dialog[id^='role-modal-']", 2
    assert_select "dialog#role-modal-student-entry", 1
    assert_select "dialog#role-modal-teacher-entry", 1
  end

  test "the student modal offers to sign in or to create an account" do
    get root_url

    assert_select "dialog#role-modal-student-entry" do
      assert_select "a[href='#{new_session_path}']", text: "Se connecter"
      assert_select "a[href='#{new_student_registration_path}']", text: "Créer mon compte"
    end
    assert_no_match(/Rejoindre ma classe/, response.body)
  end

  test "the teacher modal offers to sign in or to create an account, and is formal" do
    get root_url

    assert_select "dialog#role-modal-teacher-entry" do
      assert_select "a[href='#{new_session_path}']", text: "Se connecter"
      assert_select "a[href='#{new_teacher_registration_path}']", text: "Créer un compte"
    end
    assert_no_match INFORMAL, css_select("dialog#role-modal-teacher-entry").first.text
  end

  test "RH-02: each role modal names the tab by its own title while it is open" do
    get root_url

    assert_select "[data-controller=modal][data-modal-document-title-value='Tu es élève ? · Lnclass'] dialog#role-modal-student-entry"
    assert_select "[data-controller=modal][data-modal-document-title-value='Vous êtes enseignant ? · Lnclass'] dialog#role-modal-teacher-entry"
    assert_select "title", text: "Accueil · Lnclass"
  end

  # Choix du porteur du 2026-10-03 : le chapeau (ordinateur) dit les trois gestes de l'élève.
  test "the lead says what the student does: revise, practise with the correction, prepare the tests" do
    get root_url

    assert_select "main h1 + p", "Révise l'essentiel du cours, fais tes exercices avec la correction et prépare tes interros avec tes enseignants."
    assert_no_match(/essentielle/i, response.body)
  end

  test "RH-04: the photo is the current one, cropped in portrait: a WebP under 100 Ko with its dimensions and its alternative text" do
    get root_url

    assert_select "main img[src$='.webp'][width='505'][height='640'][alt=?]", I18n.t("homepage.index.photo_alt"), 1
    assert_select "img:not([width]), img:not([height])", 0

    %w[student student-portrait].each do |name|
      photo = Rails.root.join("app/assets/images/homepage/#{name}.webp")
      assert_operator photo.size, :<=, 100.kilobytes, "la photo #{name} pèse #{photo.size / 1024} Ko"
    end
    assert_not Rails.root.join("app/assets/images/homepage/student.png").exist?, "le PNG de 1,3 Mo doit disparaître"
  end

  test "RH-05: on a computer, the subjects of the student grid in the tone of their category, and nothing more" do
    get root_url

    badges = css_select("#matieres > span")

    assert_equal SUBJECTS, badges.map { it.text.squish }
    assert_equal [ "bg-brand-soft" ] * 3 + [ "bg-gold/20" ] * 4, badges.map { it["class"][%r{bg-[\w/-]+}] }
    assert_select "#matieres.hidden.lg\\:flex"
    assert_no_match(/et plus encore/i, response.body)
  end

  # CC-22 (UDR-0113 §3.9) : dès un cours publié, la bande lit les matières publiées, dans l'ordre du programme, chacune vers sa page.
  test "CC-22: the subjects with a published course lead to their page, in the program order" do
    level = create_level
    create_course(level:, material: create_material(name: "SVT"))
    create_course(level:, material: create_material(name: "Mathématiques"))
    create_course(level:, material: create_material(name: "Philosophie", category: "literature"), status: "draft")

    get root_url

    links = css_select("#matieres a")
    assert_equal [ [ "Mathématiques", "/matieres/mathematiques" ], [ "SVT", "/matieres/svt" ] ], links.map { [ it.text.squish, it["href"] ] }
    assert_select "#matieres a span", minimum: 2
    assert_no_match(/Philosophie/, css_select("#matieres").first.text)
  end

  test "CC-22: without a published course, the seven subjects stay, without link" do
    create_course(status: "draft")

    get root_url

    assert_select "#matieres a", 0
    assert_select "#matieres > span", SUBJECTS.size
    assert_select "a[href='/niveaux']", 0
  end

  test "every link is recognized by the router" do
    pilot_flags!(school_space_enabled: true)

    get root_url

    links = css_select("a[href]").map { it["href"] }

    assert_not_empty links
    links.each do |href|
      assert Rails.application.routes.recognize_path(href)[:controller], "#{href} n'est reconnu par aucune route"
    end
  end

  test "no button is left without an action" do
    pilot_flags!(school_space_enabled: true)

    get root_url

    css_select("button").each do |button|
      assert(button["data-action"].present? || button["type"] == "submit", "bouton sans action : #{button.text.squish}")
    end
  end

  # CA-A2 : tant que le drapeau est éteint (jusqu'au 2 novembre), ni lien ni fenêtre « Espace établissement ».
  test "CA-A2: with the flag off, there is no « Espace établissement », no link, no window, no registration of the direction" do
    pilot_flags!(school_space_enabled: false)

    get root_url

    assert_no_match(/Espace établissement/i, response.body)
    assert_select "dialog[id^='role-modal-']", 2
    assert_select "dialog#role-modal-school-entry", 0
    assert_select "a[href='#{new_school_staff_registration_path}']", 0
    assert_select "button[aria-controls='role-modal-school-entry']", 0
  end

  test "CA-A2: with the flag on, the link and its window come back, formal, with the two ways in" do
    pilot_flags!(school_space_enabled: true)

    get root_url

    assert_select "button[aria-haspopup='dialog'][aria-controls='role-modal-school-entry']", text: "Espace établissement"
    assert_select "dialog[id^='role-modal-']", 3
    assert_select "[data-controller=modal][data-modal-document-title-value='Espace établissement · Lnclass'] dialog#role-modal-school-entry"
    assert_select "dialog#role-modal-school-entry" do
      assert_select "a[href='#{new_session_path}']", text: "Se connecter"
      assert_select "a[href='#{new_school_staff_registration_path}']", text: "Créer un compte d'établissement"
    end
    assert_no_match INFORMAL, css_select("dialog#role-modal-school-entry").first.text
  end

  # UDR-0062 §4 : l'enseignant n'assigne plus que des exercices ; la landing ne promet plus de cours assignés.
  test "the teacher is promised to assign exercises, not courses" do
    get root_url

    assert_match(/assigner des exercices/i, response.body)
    assert_no_match(/des cours et des exercices|assigner du contenu|Assigne du contenu/, response.body)
  end

  test "no price is offered (TR-03)" do
    get root_url

    assert_no_match(/Inscrire mon établissement|FCFA/, response.body)
  end

  # CA-10 (ADR-0082 §4.3) : l'icône de l'app installée ouvre « /?source=app ».
  test "CA-10: a student opening the installed app has their account dated at the server's time and lands on their home" do
    student = create_student
    sign_in_as student
    opened_at = Time.current.change(usec: 0)

    travel_to(opened_at) { get root_path(source: "app") }

    assert_redirected_to student_home_path
    assert_equal opened_at, student.reload.app_opened_at
  end

  test "CA-10: a visitor opening « /?source=app » sees the public home page, and nothing is written" do
    assert_no_queries_match(/\A\s*(UPDATE|INSERT|DELETE)/i) { get root_path(source: "app") }

    assert_response :success
    assert_select "h1", text: /chap chap/
  end

  test "CA-10: any other source is ignored: the signed-in person is redirected, their account is not dated" do
    teacher = create_teacher
    sign_in_as teacher

    [ "other", "", nil ].each do |source|
      get root_path(source:)

      assert_redirected_to teacher_home_path
    end
    assert_nil teacher.reload.app_opened_at
  end

  test "CA-10: a direction opening « /?source=app » is not counted: nothing is dated, it lands on its home as before" do
    admin = create_school_admin
    sign_in_as admin
    get root_path
    home = response.location

    assert_no_queries_match(/\A\s*UPDATE\s+"users"/i) { get root_path(source: "app") }

    assert_redirected_to home
    assert_nil admin.reload.app_opened_at
  end

  test "CA-10: a team session whose second factor is not verified has no actor: nothing is dated" do
    member = create_team_member
    post session_path, params: { session: { contact: member.contact, pin: "2468" } }

    get root_path(source: "app")

    assert_redirected_to new_identity_second_factor_path
    assert_nil member.reload.app_opened_at
  end

  test "CA-10: a failure of the recording never blocks the home: it is reported as handled, with the account" do
    student = create_student
    sign_in_as student
    repository = Repositories::Identity::UserRepository
    repository.alias_method :original_mark_app_opened, :mark_app_opened
    repository.define_method(:mark_app_opened) { |user_id:, at:, channel:| raise ActiveRecord::ConnectionTimeoutError, "pool épuisé" }

    report = assert_error_reported(ActiveRecord::ConnectionTimeoutError) { get root_path(source: "app") }

    assert_redirected_to student_home_path
    assert report.handled
    assert_equal student.id, report.context[:user_id]
    assert_nil student.reload.app_opened_at
  ensure
    repository.alias_method :mark_app_opened, :original_mark_app_opened
    repository.remove_method :original_mark_app_opened
  end

  # CA-5 (ADR-0084 §4.6) : l'onglet « Accueil » de la coque Android ouvre « /?source=android ».
  test "CA-5: a student opening the Android app has android_opened_at dated at the server's time and lands on their home" do
    student = create_student(classroom: create_classroom)
    sign_in_as student
    opened_at = Time.current.change(usec: 0)

    travel_to(opened_at) { get root_path(source: "android"), headers: { "User-Agent" => ANDROID_APP } }

    assert_redirected_to student_home_path
    assert_equal opened_at, student.reload.android_opened_at
    assert_nil student.app_opened_at
  end

  test "CA-5: « /?source=android » from a browser or another Hotwire Native shell dates nothing" do
    student = create_student(classroom: create_classroom)
    sign_in_as student

    [ BROWSER, OTHER_SHELL ].each do |agent|
      assert_no_queries_match(/\A\s*UPDATE\s+"users"/i) { get root_path(source: "android"), headers: { "User-Agent" => agent } }

      assert_redirected_to student_home_path
    end
    assert_nil student.reload.android_opened_at
    assert_nil student.app_opened_at
  end

  # CA-T5 (ADR-0086 §4.6) : l'onglet « Accueil » de « Lnclass Teacher » ouvre aussi « /?source=android ».
  test "CA-T5: a teacher opening Lnclass Teacher has android_opened_at dated at the server's time and lands on their home" do
    teacher = create_teacher
    sign_in_as teacher
    opened_at = Time.current.change(usec: 0)

    travel_to(opened_at) { get root_path(source: "android"), headers: { "User-Agent" => TEACHER_APP } }

    assert_redirected_to teacher_home_path
    assert_equal opened_at, teacher.reload.android_opened_at
    assert_nil teacher.app_opened_at
  end

  test "CA-T5: « /?source=android » typed by a teacher in a browser dates nothing" do
    teacher = create_teacher
    sign_in_as teacher

    assert_no_queries_match(/\A\s*UPDATE\s+"users"/i) { get root_path(source: "android"), headers: { "User-Agent" => BROWSER } }

    assert_redirected_to teacher_home_path
    assert_nil teacher.reload.android_opened_at
  end

  test "CA-5: « /?source=app » keeps dating the installed web app, even inside the Android app" do
    student = create_student(classroom: create_classroom)
    sign_in_as student

    get root_path(source: "app"), headers: { "User-Agent" => ANDROID_APP }

    assert_redirected_to student_home_path
    assert_not_nil student.reload.app_opened_at
    assert_nil student.android_opened_at
  end
end

require "test_helper"

# ADR-0050: sign-in by phone number and PIN, one message on failure, rate limit, lockout, sign-out.
class Identity::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "the sign-in page shows the form" do
    get new_session_path

    assert_response :success
    assert_select "h1", text: "Connexion"
    assert_select "input[type=tel][name='session[contact]'][maxlength='15'][placeholder='07 00 00 00 00']"
    assert_select "input[type=password][name='session[pin]'][inputmode=numeric]"
    assert_select "a[href='#{new_identity_pin_reset_path}']", text: "Code secret oublié ?"
  end

  test "FU-03, FU-19: the page is « Connexion · Lnclass », its logo leads home, the number is the autofocus target" do
    get new_session_path

    assert_select "title", "Connexion · Lnclass"
    assert_select "a[href='#{root_path}'][aria-label='Lnclass, accueil'] img[alt='']", 2
    assert_select "input[name='session[contact]'][autocomplete=username][data-autofocus-target=field]:not([autofocus])"
    assert_select "input[name='session[pin]'][autocomplete=current-password]:not([data-autofocus-target])"
    assert_select "details summary .sr-only", "Aide : Code secret"
    assert_select "details", text: /Code secret de 4 chiffres, choisi à l'inscription/
  end

  # UDR-0060 §3.2, §3.4: one title, one form, one action, the same for every role.
  test "UDR-0060: the sign-in page says each thing once, with the card title as its only h1" do
    get new_session_path

    assert_select "h1", count: 1
    assert_select "h1", text: "Connexion"
    assert_select "h2", text: "Connexion", count: 0
    assert_select "p", text: "Heureux de vous revoir"
    assert_no_match "Élève · Enseignant · Équipe", response.body
    assert_no_match "Connectez-vous avec votre numéro", response.body
    assert_select "#session_pin_hint", 0
    assert_select "details div", text: "Code secret de 4 chiffres, choisi à l'inscription."
    assert_equal 1, response.body.scan("4 chiffres").size
    assert_select "a[href=?].min-h-tap", new_identity_pin_reset_path, text: "Code secret oublié ?"
  end

  test "UDR-0060 §3.2: the two columns start at lg; below, the welcome column is hidden" do
    get new_session_path

    assert_select "main.grid[class~='lg:grid-cols-2']"
    assert_select "main > section.hidden.bg-brand-soft[class~='lg:flex']"
    assert_select "main > section > div.text-center[class~='lg:hidden']"
    assert_select "main [class*='md:']", 0
  end

  test "a signed-in person who opens the sign-in page is sent home, the kept number dropped" do
    sign_in_as create_teacher
    get new_session_path

    assert_redirected_to teacher_home_path
    assert_nil session[:login_contact]
  end

  test "a signed-in person who opens the sign-in page is sent home" do
    sign_in_as create_teacher

    get new_session_path

    assert_redirected_to teacher_home_path
  end

  test "a student with a classroom lands on the student home" do
    student = create_student(classroom: create_classroom)

    post session_path, params: { session: { contact: student.contact, pin: "2468" } }

    assert_redirected_to student_home_path
    assert_response :see_other
    assert_equal "Connexion réussie", flash[:notice]
    assert_equal 1, Orm::Session.where(user: student).count
  end

  test "the number is accepted with the 00225 and 225 prefixes" do
    teacher = create_teacher

    [ "00225 #{teacher.contact}", "+225#{teacher.contact}" ].each do |contact|
      post session_path, params: { session: { contact:, pin: "2468" } }

      assert_redirected_to teacher_home_path, contact
    end
  end

  test "each sign-in opens a new Rails session and a new token" do
    student = create_student
    sign_in_as student
    first_session_id = session.id
    first_token = cookies[:session_token]

    sign_in_as student

    assert_not_equal first_session_id, session.id
    assert_not_equal first_token, cookies[:session_token]
  end

  test "a wrong PIN re-renders the form in 422 with one message and no PIN" do
    student = create_student

    post session_path, params: { session: { contact: " 01 #{student.contact[2..]}", pin: "1357" } }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "Numéro ou code secret incorrect."
    assert_select "input[name='session[contact]'][value=?]", " 01 #{student.contact[2..]}"
    assert_select "input[name='session[pin]']:not([value])"
  end

  # UDR-0060 §3.8: the pared-down page keeps the generic message; it never says whether a number exists.
  test "UDR-0060 §3.8: an unknown number and a wrong PIN read the same message, and the PIN never comes back" do
    student = create_student

    post session_path, params: { session: { contact: student.contact, pin: "1357" } }
    wrong_pin = css_select("[role=alert]").map { it.text.squish }
    assert_select "input[name='session[pin]'][type=password]:not([value])"

    post session_path, params: { session: { contact: "0799999999", pin: "1357" } }
    unknown_number = css_select("[role=alert]").map { it.text.squish }

    assert_response :unprocessable_entity
    assert_equal [ "Numéro ou code secret incorrect." ], wrong_pin
    assert_equal wrong_pin, unknown_number
    assert_select "input[name='session[pin]'][type=password]:not([value])"
    assert_select "input[value='1357']", 0
  end

  test "a teacher and a school admin sign in as before, each to their home" do
    post session_path, params: { session: { contact: create_teacher.contact, pin: "2468" } }

    assert_redirected_to teacher_home_path
    assert_equal "Connexion réussie", flash[:notice]

    delete session_path
    post session_path, params: { session: { contact: create_school_admin.contact, pin: "2468" } }

    assert_redirected_to school_admin_classrooms_path
    assert_response :see_other
    assert_equal "Connexion réussie", flash[:notice]
  end

  test "a malformed PIN is shown under its field" do
    post session_path, params: { session: { contact: "0700000000", pin: "12" } }

    assert_response :unprocessable_entity
    assert_select "#session_pin_error", text: "Le code secret compte 4 chiffres."
  end

  test "a locked number receives 429 and the unlock time" do
    student = create_student
    5.times { create_login_attempt(contact: student.contact) }

    post session_path, params: { session: { contact: student.contact, pin: "2468" } }

    assert_response :too_many_requests
    assert_select "[role=alert]", text: /Réessayez à/
  end

  test "a sixth attempt in a minute from the same address receives 429" do
    5.times { post session_path, params: { session: { contact: "0700000000", pin: "1357" } } }

    post session_path, params: { session: { contact: "0700000000", pin: "1357" } }

    assert_response :too_many_requests
    assert_select "[role=alert]", text: /Trop de tentatives en une minute/
  end

  test "signing out ends the session and returns to the landing page" do
    sign_in_as create_student

    delete session_path

    assert_redirected_to root_path
    assert_equal "Vous êtes déconnecté", flash[:notice]
    assert_equal 0, Orm::Session.count
    assert_empty cookies[:session_token].to_s
  end

  test "a team member can sign out before the second factor" do
    member = create_team_member
    post session_path, params: { session: { contact: member.contact, pin: "2468" } }

    delete session_path

    assert_redirected_to root_path
    assert_equal 0, Orm::Session.count
  end

  # ADR-0084 §4.5, ADR-0086 §4.5, UDR-0082 §3.4: the two Android shells recognised by their User-Agent (ADR-0086 §4.1).
  APP_USER_AGENT = "Mozilla/5.0 (Linux; Android 13; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 " \
                   "Hotwire Native Android; LnclassStudentAndroid/1.0".freeze
  TEACHER_APP_USER_AGENT = APP_USER_AGENT.sub("LnclassStudentAndroid", "LnclassTeacherAndroid").freeze
  STUDENT_STORE_URL = "https://play.google.com/store/apps/details?id=com.lnclass.student".freeze
  TEACHER_STORE_URL = "https://play.google.com/store/apps/details?id=com.lnclass.teacher".freeze

  def with_store_urls(student: STUDENT_STORE_URL, teacher: TEACHER_STORE_URL)
    previous = Rails.configuration.x.android
    Rails.configuration.x.android = { apps: { student: { package_name: "com.lnclass.student", store_url: student },
                                              teacher: { package_name: "com.lnclass.teacher", store_url: teacher } },
                                      cert_fingerprints: [] }.freeze
    yield
  ensure
    Rails.configuration.x.android = previous
  end

  def sign_in_from(user_agent, user, pin: "2468", ip: "127.0.0.1")
    post session_path, params: { session: { contact: user.contact, pin: } }, headers: { "User-Agent" => user_agent },
                       env: { "REMOTE_ADDR" => ip }
  end

  def assert_refused(title:, body:, link:, href:)
    assert_response :unprocessable_entity
    assert_select "#wrong-app[role=alert]" do
      assert_select "p", text: title
      assert_select "p", text: /#{Regexp.escape(body)}/
      assert_select "a[href='#{href}'][target=_blank][rel=noopener]", text: link
    end
    assert_equal 0, Orm::Session.count
    assert_empty cookies[:session_token].to_s
    assert_select "input[name='session[contact]']:not([value])"
    assert_select "input[name='session[pin]']:not([value])"
  end

  test "CA-3, CA-T3: in the students' app, a teacher with the right PIN is sent to Lnclass Teacher, with no session" do
    sign_in_from APP_USER_AGENT, create_teacher

    assert_refused title: "Utilisez Lnclass Teacher", link: "Ouvrir Lnclass Teacher", href: "https://lnclass.com",
                   body: "Cette app est réservée aux élèves. Les enseignants ont leur app, Lnclass Teacher."
  end

  test "CA-T3: in the students' app, the teacher's link is the Lnclass Teacher Play Store page once it is published" do
    with_store_urls { sign_in_from APP_USER_AGENT, create_teacher }

    assert_refused title: "Utilisez Lnclass Teacher", link: "Ouvrir Lnclass Teacher", href: TEACHER_STORE_URL,
                   body: "Cette app est réservée aux élèves. Les enseignants ont leur app, Lnclass Teacher."
  end

  test "CA-3: in the students' app, a team member is refused before any second factor and sent to the website" do
    with_store_urls { sign_in_from APP_USER_AGENT, create_team_member }

    assert_refused title: "Cette app est réservée aux élèves", body: "Direction et équipe : continuez sur le site.",
                   link: "Ouvrir lnclass.com", href: "https://lnclass.com"
  end

  test "CA-T3: in the teachers' app, a student with the right PIN is sent to the Lnclass app, with no session" do
    sign_in_from TEACHER_APP_USER_AGENT, create_student(classroom: create_classroom)

    assert_refused title: "Utilisez l'app Lnclass", link: "Ouvrir Lnclass", href: "https://lnclass.com",
                   body: "Cette app est réservée aux enseignants. Les élèves ont leur app, Lnclass."
  end

  test "CA-T3: in the teachers' app, the student's link is the Lnclass Play Store page once it is published" do
    with_store_urls { sign_in_from TEACHER_APP_USER_AGENT, create_student(classroom: create_classroom) }

    assert_refused title: "Utilisez l'app Lnclass", link: "Ouvrir Lnclass", href: STUDENT_STORE_URL,
                   body: "Cette app est réservée aux enseignants. Les élèves ont leur app, Lnclass."
  end

  test "CA-T3: in the teachers' app, the school admin is sent to the website, even with published apps" do
    with_store_urls { sign_in_from TEACHER_APP_USER_AGENT, create_school_admin }

    assert_refused title: "Cette app est réservée aux enseignants", body: "Direction et équipe : continuez sur le site.",
                   link: "Ouvrir lnclass.com", href: "https://lnclass.com"
  end

  test "CA-3, CA-T3: in either app, a wrong PIN reads exactly a wrong-PIN message, whatever the role" do
    users = [ create_student, create_teacher, create_school_admin ]
    [ APP_USER_AGENT, TEACHER_APP_USER_AGENT ].product(users).each_with_index do |(agent, user), index|
      # Une adresse par essai : le plafond de 5 envois par minute et par adresse n'est pas l'objet du test.
      sign_in_from agent, user, pin: "1357", ip: "10.0.0.#{index + 1}"

      assert_response :unprocessable_entity
      assert_equal [ "Numéro ou code secret incorrect." ], css_select("[role=alert]").map { it.text.squish }
      assert_select "#wrong-app", 0
    end
  end

  test "CA-4: in the students' app, a student with the right PIN lands on the student home" do
    student = create_student(classroom: create_classroom)

    sign_in_from APP_USER_AGENT, student

    assert_redirected_to student_home_path
    assert_equal 1, Orm::Session.where(user: student).count
    assert_not_empty cookies[:session_token].to_s
  end

  test "CA-T4: in the teachers' app, a teacher with the right PIN lands on the teacher home" do
    teacher = create_teacher

    sign_in_from TEACHER_APP_USER_AGENT, teacher

    assert_redirected_to teacher_home_path
    assert_equal 1, Orm::Session.where(user: teacher).count
    assert_not_empty cookies[:session_token].to_s
  end
end

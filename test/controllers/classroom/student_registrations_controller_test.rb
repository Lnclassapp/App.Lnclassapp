require "test_helper"

# IL-01, IL-02 (the page), IL-05, IL-06, IL-07, IL-08, IL-09, IL-10, IL-19, IL-20, IL-23 server side (ADR-0085,
# UDR-0081 §3.1 to §3.3): one public sign-up page in three sections (your classroom, you, secret code). The class code
# is back (ADR code-de-classe-a-six-caracteres): its field is the sign-up screen's business (Lot B), the code itself is
# resolved by RegisterStudent. The classroom is chosen in four chained lists (DRENA, school, level, classroom), or given by a classroom link;
# the student enters it at once, signed in. UDR-0091 (CA-6): the same cascade as « Choisis ta classe », in three steps.
class Classroom::StudentRegistrationsControllerTest < ActionDispatch::IntegrationTest
  ERRORS = "activemodel.errors.models.dtos/classroom/student_registration_input.attributes".freeze
  PAGE = "classroom.student_registrations.new".freeze
  FORM = "classroom.student_registrations.form".freeze
  PICKER = "classroom.student_registrations.class_picker".freeze

  setup do
    @drena = create_drena(name: "Abidjan 1")
    @school = create_school(drena: @drena, name: "Lycée Moderne de Cocody")
    @level = create_level(name: "3ème")
    @classroom = create_classroom(school: @school, level: @level, name: "3e 2")
  end

  def registration_params(**overrides)
    { last_name: "KOUASSI", first_name: "Aya Marie", gender: "female", contact: "07 01 02 03 04", pin: "4821",
      pin_confirmation: "4821", drena_public_id: @drena.public_id, school_public_id: @school.public_id, level_slug: @level.slug,
      classroom_public_id: @classroom.public_id, **overrides }
  end

  def register(**overrides) = post(student_registrations_path, params: { student_registration: registration_params(**overrides) })
  def new_student = Orm::User.find_by!(contact: "0701020304")
  def memberships = Orm::ClassroomStudent.where(student: new_student)

  def assert_refused(attribute, message, status: :unprocessable_entity)
    assert_response status
    assert_select "#student_registration_#{attribute}_error", text: message
    assert_not Orm::User.exists?(contact: "0701020304")
  end

  STEPS = "classroom.student_registrations.form".freeze
  SIGNUP = "#student-signup".freeze

  def start_step = css_select(SIGNUP).first["data-classroom--signup-steps-start-value"].to_i

  # CA-C1, UDR « inscription élève en trois étapes » §3.1, §3.2: three fieldsets in order, the code field first, the cascade
  # behind « Je n'ai pas de code », « Étape 1 sur 3 », the welcome card, and no « Continuer » button outside the no-JS fallback.
  test "CA-C1: step 1 of 3 opens on the class code, with the welcome card and no « Continuer » button" do
    get new_student_registration_path

    assert_response :success
    assert_equal 1, start_step
    assert_select "#{SIGNUP}[data-controller~='classroom--signup-steps']"
    assert_select "#signup-step-counter", text: I18n.t("#{STEPS}.step_counter", n: 1)
    assert_select "#signup-progress li", 3
    assert_select "#signup-live[aria-live=polite]"
    assert_select "#signup-welcome", text: /Bienvenue sur Lnclass/
    assert_select "h1", text: I18n.t("#{PAGE}.title"), count: 1
    assert_select "#signup-back[hidden]"
    assert_equal [ I18n.t("#{STEPS}.classroom"), I18n.t("#{STEPS}.you"), I18n.t("#{STEPS}.security") ],
                 css_select("fieldset[data-classroom--signup-steps-target=step] > legend").map { it.text.squish }
    assert_select "fieldset[data-classroom--signup-steps-target=step]", 3
    assert_select "input#student_registration_join_code[maxlength='6'][autocomplete=off][inputmode=text]" \
                  "[autocapitalize=characters].font-mono[data-classroom--signup-steps-target=code]"
    assert_select "#student_registration_join_code_hint", text: I18n.t("#{STEPS}.code_hint")
    assert_select "#signup-code-checking[hidden]", text: I18n.t("#{STEPS}.checking")
    assert_select "turbo-frame#classroom_code_preview[aria-live=polite]"
    assert_select "input#signup-no-code[type=checkbox]:not([checked])"
    assert_select "label[for=signup-no-code]", text: I18n.t("#{STEPS}.no_code")
    # The cascade is the fallback: it stays in the page, shown by the checkbox.
    assert_select "#signup-cascade select[name='student_registration[drena_public_id]']"
    visible_buttons = css_select("form button").reject { it.ancestors("noscript").any? }
    assert_empty visible_buttons.select { it.text.squish == I18n.t("#{PICKER}.continue") }
    assert_equal 1, visible_buttons.count { it["type"] == "submit" }
  end

  test "UDR §3.1: the help, the logo, the dividers and the terms line under the button" do
    get new_student_registration_path

    assert_select "#signup-header a[href='/'][aria-label]"
    assert_select "#signup-header #auth-help [aria-controls=help-sheet]", text: "Besoin d'aide ?"
    assert_select "dialog#help-sheet", 1
    assert_select "#student-registration-submit + p.text-xs a[href=?]", terms_path
    assert_select "#student-registration-submit + p a[href=?]", privacy_path
    assert_select "#signup-signin a[href=?]", new_session_path, text: I18n.t("#{PAGE}.sign_in")
    assert_select "aside#auth-welcome-panel", 0
  end

  test "UDR §3.8: the submit says « Création… » while sent, and the steps have a legend, the title focusable" do
    get new_student_registration_path

    assert_select "button#student-registration-submit[data-turbo-submits-with='#{I18n.t("#{STEPS}.submitting")}']"
    assert_select "button#student-registration-submit[data-classroom--class-picker-target=submit]", 0
    assert_select "fieldset > legend[tabindex='-1']", 3
  end

  test "CA-C1: the gender stays two pills that are real radios, 44 px, the phone and the secret code fields are kept" do
    get new_student_registration_path

    assert_select "#student-registration-gender label.h-11[class~='has-checked:bg-brand-strong']", count: 2 do |pills|
      assert_equal [ I18n.t("genders.male"), I18n.t("genders.female") ].sort, pills.map { it.text.squish }.sort
    end
    assert_select "#student-registration-gender label > input[type=radio][name='student_registration[gender]'][required]", count: 2
    assert_select "input[type=tel][name='student_registration[contact]'][data-identity--phone-digits-target=input]"
    assert_select "form#student-registration-form[data-controller~='identity--pin-match']"
  end

  # CA-C7: without JavaScript every step is in the page, one under the other, and the form posts as before.
  test "CA-C7: no step is hidden by the server, so without JavaScript the three steps are visible" do
    get new_student_registration_path

    assert_select "fieldset[data-classroom--signup-steps-target=step][hidden]", 0
    assert_select "form#student-registration-form fieldset[data-step='1'] ~ fieldset[data-step='2'] ~ fieldset[data-step='3']"
  end

  # Chantier ci-rejeu-cible: the delay before step 2 moves on is the controller's own (1 s) unless the environment sets it;
  # only the tests do (100 ms), so the production page carries no delay attribute.
  test "the step-2 delay is set by the test environment alone; unset, the page leaves the controller's default" do
    get new_student_registration_path
    assert_select "#student-signup[data-classroom--signup-steps-delay-value='100']"
    get new_teacher_registration_path
    assert_select "#teacher-signup[data-classroom--signup-steps-delay-value='100']"

    delay = Rails.configuration.x.signup_steps_delay_ms
    Rails.configuration.x.signup_steps_delay_ms = nil
    get new_student_registration_path
    assert_select "#student-signup[data-controller='classroom--signup-steps']:not([data-classroom--signup-steps-delay-value])"
    get new_teacher_registration_path
    assert_select "#teacher-signup[data-controller='classroom--signup-steps']:not([data-classroom--signup-steps-delay-value])"
  ensure
    Rails.configuration.x.signup_steps_delay_ms = delay
  end

  # CA-C8, UDR « inscription élève en trois étapes » §3.5 bis: on a computer, one blue panel on the left, the same whatever the step
  # (the page is the same; only the step marked `aria-current` changes), shown from lg up and replacing the three-segment bar.
  test "CA-C8: the panel carries the welcome, the three steps in a list with the current one marked, and « Déjà un compte ? »" do
    get new_student_registration_path

    assert_select "#signup-panel.hidden.lg\\:flex.bg-brand-strong.text-white" do
      assert_select "h1", text: I18n.t("#{PAGE}.welcome")
      assert_select "ol#signup-panel-steps li[data-step]", 3
      assert_select "ol#signup-panel-steps li[aria-current=step]", 1
      assert_select "ol#signup-panel-steps li[data-step='1'][aria-current=step]", text: /#{I18n.t("#{FORM}.classroom")}/
      assert_select "a[href=?]", new_session_path, text: I18n.t("#{PAGE}.sign_in")
      assert_select "p", text: /#{I18n.t("#{PAGE}.have_account")}/
    end
    assert_select "#signup-progress.lg\\:hidden"
    assert_select "#signup-welcome.lg\\:hidden"
    assert_select "#signup-signin.lg\\:hidden"
  end

  test "CA-C8: a link arrives at step 2, the panel marks step 2 and step 1 done" do
    get join_classroom_path(@classroom.reload.link_token)

    assert_select "#signup-panel ol li[aria-current=step]", 1
    assert_select "#signup-panel ol li[data-step='2'][aria-current=step]"
    assert_select "#signup-panel ol li[data-step='1'] [data-done]:not([hidden])", 1
  end

  # CA-C9: the class found is shown in the panel, under step 1, with « Ce n'est pas ta classe ? ›»; the recap above the form is kept
  # for the phone and hidden from lg up.
  test "CA-C9: the link's class is in the panel under step 1, and the recap above the form is hidden from lg up" do
    get join_classroom_path(@classroom.reload.link_token)

    assert_select "#signup-panel ol li[data-step='1'] #signup-panel-recap:not([hidden])", text: /3e 2.*Lycée Moderne de Cocody/m
    assert_select "#signup-panel #panel-other-classroom[href=?]", new_student_registration_path
    assert_select "#signup-classroom-recap.lg\\:hidden"
  end

  test "CA-C9: without a class found, the panel recap is empty and hidden" do
    get new_student_registration_path

    assert_select "#signup-panel-recap[hidden]", 1
    assert_select "#signup-panel-recap:not([hidden])", 0
  end

  test "CA-C3: a valid classroom link opens at step 2 with the recap and the welcome card, no step 1, no « Retour »" do
    get join_classroom_path(@classroom.reload.link_token)

    assert_response :success
    assert_equal 2, start_step
    assert_select "#signup-step-counter", text: I18n.t("#{STEPS}.step_counter", n: 2)
    assert_select "fieldset[data-step='1']", 0
    assert_select "fieldset[data-step]", 2
    assert_select "#signup-classroom-recap", text: /3e 2.*Lycée Moderne de Cocody/m
    assert_select "#signup-classroom-recap a#other-classroom[href=?]", new_student_registration_path
    assert_select "#signup-back[hidden]"
    assert_select "#signup-welcome", text: /Bienvenue sur Lnclass/
    assert_select "input[name='student_registration[join_code]']", 0
  end

  # CA-C5: the code is posted over HTTP too (the field is permitted), and joined_via says « code ».
  test "CA-C5: signing up with the class code enters the classroom, way « code », whatever classroom is sent" do
    other = create_classroom(school: @school, level: @level, name: "3e 3")

    register(join_code: @classroom.reload.join_code.upcase, classroom_public_id: other.public_id)

    assert_redirected_to student_home_path
    assert_equal [ [ @classroom.id, "code" ] ], memberships.pluck(:classroom_id, :joined_via)
  end

  test "CA-C5: the code alone is enough, without any cascade choice" do
    register(join_code: @classroom.reload.join_code, classroom_public_id: nil, drena_public_id: nil, school_public_id: nil,
             level_slug: nil)

    assert_redirected_to student_home_path
    assert_equal [ "code" ], memberships.pluck(:joined_via)
  end

  test "CA-B3, CA-C6: an unknown code is refused under the code field and reopens step 1, the other entries kept" do
    register(join_code: "zzzzzz", classroom_public_id: nil)

    assert_refused :join_code, I18n.t("#{ERRORS}.join_code.unknown")
    assert_equal 1, start_step
    assert_select "input[name='student_registration[last_name]'][value='KOUASSI']"
    assert_select "input#student_registration_join_code[aria-invalid=true][value='zzzzzz']"
  end

  test "CA-B3: the code of an archived classroom is refused like an unknown code, no account" do
    archived = create_classroom(school: @school, level: @level, name: "3e 3", status: "archived")

    register(join_code: archived.reload.join_code, classroom_public_id: nil)

    assert_refused :join_code, I18n.t("#{ERRORS}.join_code.unknown")
    assert_equal 1, start_step
  end

  test "CA-C6: an error on the number reopens step 2, on the secret code step 3, on the classroom step 1" do
    register(contact: "070102030")
    assert_equal 2, start_step

    register(pin_confirmation: "1357")
    assert_equal 3, start_step

    register(classroom_public_id: "")
    assert_equal 1, start_step

    register(last_name: "", pin_confirmation: "1357")
    assert_equal 2, start_step, "the first step that holds an error opens"
  end

  test "CA-C6: after a code accepted and an error on the number, step 2 opens with the class recap" do
    code = @classroom.reload.join_code
    register(join_code: code, contact: "070102030")

    assert_response :unprocessable_entity
    assert_equal 2, start_step
    assert_select "#signup-classroom-recap", text: /3e 2.*Lycée Moderne de Cocody/m
    assert_select "#signup-classroom-recap a#other-classroom[data-action='click->classroom--signup-steps#restart']"
    assert_select "input#student_registration_join_code[value='#{code}']"
    assert_select "#student_registration_contact_error", text: I18n.t("#{ERRORS}.contact.invalid")
  end

  test "UDR §3.2: after a cascade choice and an error, the checkbox is ticked so the cascade stays open" do
    register(pin_confirmation: "1357")

    assert_select "input#signup-no-code[checked]"
    assert_select "turbo-frame#picker_classrooms input[type=radio][checked][value='#{@classroom.public_id}']"
  end

  test "UDR §3.5: the general refusal (full classroom) shows at the top of the open step" do
    @classroom.update!(max_students: 1)
    create_student(classroom: @classroom)

    register

    assert_response :forbidden
    assert_equal 1, start_step
    assert_select "fieldset[data-step='1'] #student-registration-refusal[role=alert]", text: I18n.t("#{ERRORS}.base.classroom_full")
  end

  # CA-B4: the sign-up shares the counter « classroom/joins » (10 a minute and per address) with /c/<token> and the check of a code.
  test "CA-B4: five checks of a code and five openings of a link make the sign-up receive 429, with the code message at step 1" do
    token = @classroom.reload.link_token
    5.times { get classroom_code_path("abcdef") }
    5.times { get join_classroom_path(token) }

    register

    assert_response :too_many_requests
    assert_equal 1, start_step
    assert_select "fieldset[data-step='1'] #signup-rate-limited[role=alert]", text: I18n.t("#{STEPS}.rate_limited")
    assert_not Orm::User.exists?(contact: "0701020304")
  end

  test "a missing gender is refused under the gender, the fieldset described by it and both radios invalid" do
    register(gender: "")

    assert_refused :gender, I18n.t("#{ERRORS}.gender.inclusion")
    assert_select "fieldset#student-registration-gender[aria-describedby=student_registration_gender_error]"
    assert_select "#student-registration-gender input[type=radio][aria-invalid=true]", count: 2
  end

  # CA-6: a number of 9 digits comes back in 422, its message under the field, the field marked for the focus.
  test "CA-6: a 9-digit number is refused under the number, the field invalid and first in error" do
    register(contact: "070102030")

    assert_refused :contact, I18n.t("#{ERRORS}.contact.invalid")
    assert_select "#student-registration-section-you input#student_registration_contact[aria-invalid=true]" \
                  "[aria-describedby~=student_registration_contact_error]"
    assert_select "[aria-invalid=true]", 1
  end

  test "IL-04 without JavaScript: each choice sent in GET lists the next step in the page" do
    create_school(drena: @drena, name: "Lycée fermé", status: "inactive")

    get new_student_registration_path, params: { student_registration: { drena_public_id: @drena.public_id } }

    assert_response :success
    assert_select "select[name='student_registration[drena_public_id]'] option[selected][value='#{@drena.public_id}']"
    assert_select "turbo-frame#picker_schools select[name='student_registration[school_public_id]']" \
                  "[data-action='change->classroom--class-picker#loadLevels'] option[value='#{@school.public_id}']",
                  text: "Lycée Moderne de Cocody"
    assert_no_match(/Lycée fermé/, response.body)
    assert_select "turbo-frame#picker_levels *", 0

    get new_student_registration_path,
        params: { student_registration: { drena_public_id: @drena.public_id, school_public_id: @school.public_id } }

    assert_select "turbo-frame#picker_schools option[selected][value='#{@school.public_id}']"
    assert_select "#class-picker-school-summary", text: /Lycée Moderne de Cocody/
    # « Changer » sans JavaScript : la DRENA seule revient ; nom, prénoms et contact sont perdus (dette, journal).
    assert_select "#class-picker-school-summary a[href='#{new_student_registration_path(student_registration: { drena_public_id: @drena.public_id })}']",
                  text: I18n.t("#{PICKER}.change")
    assert_select "turbo-frame#picker_levels input[type=radio][name='student_registration[level_slug]']" \
                  "[data-action='change->classroom--class-picker#loadClassrooms'][value='#{@level.slug}']"
    assert_select "turbo-frame#picker_levels label", text: "3ème"
    assert_select "turbo-frame#picker_classrooms *", 0

    get new_student_registration_path,
        params: { student_registration: registration_params(classroom_public_id: nil, pin: "4821") }

    assert_select "turbo-frame#picker_levels input[type=radio][checked][value='#{@level.slug}']"
    assert_select "fieldset > legend", text: "3 #{I18n.t("#{PICKER}.step_classroom")}"
    # UDR-0091 §3.6 : les radios vivent dans le fieldset de leur étape, qui les nomme.
    assert_select "fieldset#class-picker-step-level turbo-frame#picker_levels input[type=radio]", 1
    assert_select "fieldset#class-picker-step-classroom turbo-frame#picker_classrooms input[type=radio]", 1
    assert_select "turbo-frame#picker_classrooms input[type=radio][name='student_registration[classroom_public_id]']" \
                  "[value='#{@classroom.public_id}']:not([checked])"
    assert_select "input[name='student_registration[last_name]'][value='KOUASSI']"
    assert_select "input[name='student_registration[first_name]'][value='Aya Marie']"
    assert_select "input[name='student_registration[pin]'][value]", 0
  end

  test "a choice that does not belong to its parent empties the lists after it" do
    other = create_school(drena: create_drena)

    get new_student_registration_path,
        params: { student_registration: registration_params(school_public_id: other.public_id) }

    assert_response :success
    assert_select "turbo-frame#picker_schools option[selected]", 0
    assert_select "turbo-frame#picker_levels *", 0
    assert_select "turbo-frame#picker_classrooms *", 0

    get new_student_registration_path, params: { student_registration: { drena_public_id: "drn-inconnue" } }

    assert_select "turbo-frame#picker_schools *", 0
  end

  # Relecture sécurité de la PR 203 : une chaîne à la place des choix ne lève plus d'exception (500) ; elle est ignorée.
  test "choices sent as a string instead of a hash are ignored, the page opens empty" do
    get new_student_registration_path, params: { student_registration: "x" }

    assert_response :success
    %w[picker_schools picker_levels picker_classrooms].each { assert_select "turbo-frame##{it} *", 0 }
  end

  test "IL-05: a full classroom is listed, disabled, with « Complète » in its label" do
    @classroom.update!(max_students: 1)
    create_student(classroom: @classroom)

    get new_student_registration_path, params: { student_registration: registration_params(classroom_public_id: nil) }

    assert_select "turbo-frame#picker_classrooms label.opacity-60", text: /3e 2/ do
      assert_select "input[type=radio][disabled][value='#{@classroom.public_id}']"
      assert_select "span", text: I18n.t("#{PICKER}.full")
    end
  end

  test "IL-06: a school without an active classroom, or a DRENA without an active school, says it is not on Lnclass yet" do
    empty = create_school(drena: @drena, name: "Collège sans classe")

    get new_student_registration_path,
        params: { student_registration: { drena_public_id: @drena.public_id, school_public_id: empty.public_id } }

    assert_select "turbo-frame#picker_levels", text: /#{Regexp.escape(I18n.t("#{PICKER}.not_found_title"))}/
    assert_select "turbo-frame#picker_levels", text: /#{Regexp.escape(I18n.t("#{PICKER}.not_found_description"))}/
    assert_select "turbo-frame#picker_levels input", 0

    get new_student_registration_path, params: { student_registration: { drena_public_id: create_drena.public_id } }

    assert_select "turbo-frame#picker_schools", text: /#{Regexp.escape(I18n.t("#{PICKER}.not_found_title"))}/
    assert_select "turbo-frame#picker_schools select", 0
  end

  test "IL-01: a standard sign-up enters the classroom at once, way « standard », signed in and welcomed" do
    freeze_time do
      register

      assert_redirected_to student_home_path
      assert_response :see_other
      assert_equal I18n.t("classroom.student_registrations.create.welcome"), flash[:notice]
      assert_equal [ "student", nil, "KOUASSI", "Aya Marie", "female" ],
                   [ new_student.role, new_student.team_role, new_student.last_name, new_student.first_name, new_student.gender ]
      assert_equal [ [ @classroom.id, true, Time.current, nil, "standard" ] ],
                   memberships.pluck(:classroom_id, :primary, :joined_at, :left_at, :joined_via)
      assert Orm::User.authenticate_by(contact: "0701020304", pin: "4821")
      assert_equal 1, Orm::Session.where(user: new_student).count
      assert cookies[:session_token].present?
    end
  end

  test "IL-03: a classroom without any teacher takes the student at once" do
    assert_empty Orm::TeacherClassroom.where(classroom: @classroom)

    register

    assert_equal [ @classroom.id ], memberships.where(left_at: nil).pluck(:classroom_id)
  end

  test "TR-cadre-1: a role added by hand is ignored, the account is a student" do
    post student_registrations_path, params: { student_registration: registration_params(role: "team", team_role: "admin") }

    assert_redirected_to student_home_path
    assert_equal [ "student", nil ], Orm::User.where(contact: "0701020304").pick(:role, :team_role)
  end

test "IL-20 (IE-03): the name and the first names are kept as typed, the spaces reduced" do
  register(last_name: "KONÉ  OUATTARA", first_name: "Awa")

  assert_redirected_to student_home_path
  assert_equal [ "KONÉ OUATTARA", "Awa" ], [ new_student.last_name, new_student.first_name ]
end

test "IL-20 (IE-05): missing first names are refused in 422 under their own field, the name kept" do
  register(first_name: " ")

  assert_refused :first_name, I18n.t("#{ERRORS}.first_name.blank")
  assert_select "input[name='student_registration[first_name]'][aria-invalid=true]"
  assert_select "input[name='student_registration[last_name]'][value='KOUASSI']"
end

test "ADR-0037: a forbidden character is refused under its field, the entry kept" do
  register(last_name: "Kouassi", first_name: "Aya 2")

  assert_refused :first_name, I18n.t("#{ERRORS}.first_name.invalid")
  assert_select "input[name='student_registration[first_name]'][value='Aya 2']"
end

  test "IL-20 (IE-17, IE-19): different codes are refused in 422, the entries and the four choices kept, never the secret codes" do
    register(contact: "+225 07 01 02 03 04", pin_confirmation: "1357")

    assert_refused :pin_confirmation, I18n.t("#{ERRORS}.pin_confirmation.confirmation")
    assert_select "input[name='student_registration[contact]'][value='+225 07 01 02 03 04']"
    assert_select "input[name='student_registration[last_name]'][value='KOUASSI']"
    assert_select "input[name='student_registration[gender]'][value=female][checked]"
    assert_select "input[name='student_registration[pin]'][value]", count: 0
    assert_select "select[name='student_registration[drena_public_id]'] option[selected][value='#{@drena.public_id}']"
    assert_select "turbo-frame#picker_schools option[selected][value='#{@school.public_id}']"
    assert_select "turbo-frame#picker_levels input[type=radio][checked][value='#{@level.slug}']"
    assert_select "turbo-frame#picker_classrooms input[type=radio][checked][value='#{@classroom.public_id}']"

    register(contact: "+225 07 01 02 03 04")

    assert_redirected_to student_home_path
    assert Orm::User.exists?(contact: "0701020304", role: "student")
  end

  test "IL-01: no classroom chosen: the classroom is asked in 422" do
    register(classroom_public_id: "")

    assert_refused :classroom_public_id, I18n.t("#{ERRORS}.classroom_public_id.blank")
  end

  test "IL-05: a full classroom sent anyway is refused in 403 at the top of the form, no account" do
    @classroom.update!(max_students: 1)
    create_student(classroom: @classroom)

    register

    assert_response :forbidden
    assert_select "fieldset[data-step='1'] #student-registration-refusal[role=alert]", text: I18n.t("#{ERRORS}.base.classroom_full")
    assert_equal "Cette classe est complète.", I18n.t("#{ERRORS}.base.classroom_full")
    assert_not Orm::User.exists?(contact: "0701020304")
  end

  test "IL-07: an archived classroom, one of another level, school, or of a draft or inactive school: 422, no account" do
    archived = create_classroom(school: @school, level: @level, name: "3e 3", status: "archived")
    other_level = create_classroom(school: @school, level: create_level, name: "6e 1")
    elsewhere = create_classroom(school: create_school(drena: @drena), level: @level, name: "3e 1")
    drafts = %w[draft inactive].map do |status|
      create_classroom(school: create_school(drena: @drena, status:), level: @level, name: "3e 1")
    end

    [ archived, other_level, elsewhere ].each do |classroom|
      register(classroom_public_id: classroom.public_id)

      assert_refused :classroom_public_id, I18n.t("#{ERRORS}.classroom_public_id.unavailable")
    end
    drafts.each do |classroom|
      register(classroom_public_id: classroom.public_id, school_public_id: classroom.school.public_id)

      assert_refused :classroom_public_id, I18n.t("#{ERRORS}.classroom_public_id.unavailable")
    end
  end

  test "IL-19: a number already used is refused in 422 with its message, the role not revealed, no membership" do
    create_user(role: "teacher", contact: "0701020304")

    register

    assert_response :unprocessable_entity
    assert_equal 2, start_step
    assert_select "#student_registration_contact_error", text: I18n.t("#{ERRORS}.contact.taken")
    assert_equal "Ce numéro est déjà utilisé.", I18n.t("#{ERRORS}.contact.taken")
    assert_equal 0, Orm::ClassroomStudent.count
  end

  test "IL-08: signing up with the hidden link token enters the link's classroom, way « link », whatever classroom is sent" do
    other = create_classroom(school: @school, level: @level, name: "3e 3")

    register(link_token: @classroom.reload.link_token, classroom_public_id: other.public_id)

    assert_redirected_to student_home_path
    assert_equal [ [ @classroom.id, "link" ] ], memberships.pluck(:classroom_id, :joined_via)
  end

  test "an error after a valid link keeps the banner and the token, never the PINs nor the lists" do
    token = @classroom.reload.link_token

    register(link_token: token, pin_confirmation: "1357", drena_public_id: nil)

    assert_refused :pin_confirmation, I18n.t("#{ERRORS}.pin_confirmation.confirmation")
    # CA-C3 : le rappel de la classe et « Ce n'est pas ta classe ? » en tête de l'étape 2.
    assert_equal 3, start_step
    assert_select "#student-registration-section-you #signup-classroom-recap", text: /3e 2.*Lycée Moderne de Cocody/m
    assert_select "#student-registration-section-you a#other-classroom", text: I18n.t("#{FORM}.other_classroom")
    assert_select "input[type=hidden][name='student_registration[link_token]'][value='#{token}']"
    assert_select "a#other-classroom[href='#{new_student_registration_path}']"
    assert_select "select[name='student_registration[drena_public_id]'], turbo-frame#picker_schools", 0
    assert_select "#classroom-link-invalid", 0
    assert_select "input[name='student_registration[pin]'][value]", count: 0
  end

  test "IL-09: a link that became invalid before the submit falls back to the classroom chosen, way « standard »" do
    token = @classroom.reload.link_token
    @classroom.update!(link_token: "ffffffffffff")

    register(link_token: token)

    assert_redirected_to student_home_path
    assert_equal [ "standard" ], memberships.pluck(:joined_via)
  end

  test "IL-09: an invalid link and an error: the standard page with the alert" do
    register(link_token: "cccccccccccc", classroom_public_id: "")

    assert_refused :classroom_public_id, I18n.t("#{ERRORS}.classroom_public_id.blank")
    assert_select "fieldset[data-step='1'] #classroom-link-invalid[role=alert]", text: I18n.t("#{FORM}.link_invalid")
    assert_select "select[name='student_registration[drena_public_id]']"
    assert_select "input[name='student_registration[link_token]'], #signup-classroom-recap:not([hidden])", 0
  end

  test "IL-09: the standard page, opened from an invalid link, carries the alert once" do
    get join_classroom_path("cccccccccccc")
    follow_redirect!

    assert_select "#classroom-link-invalid[role=alert]", text: "Ce lien n'est plus valable. Choisis ta classe."

    get new_student_registration_path

    assert_select "#classroom-link-invalid", 0
  end

  test "PRD §3: the direction and the team who open the page are sent to their home; their POST is refused" do
    { create_school_admin => school_admin_classrooms_path, create_team_member => team_home_path }.each do |user, home|
      sign_in_as user

      get new_student_registration_path
      assert_redirected_to home

      register
      assert_response :forbidden
      assert_not Orm::User.exists?(contact: "0701020304")
      sign_out
    end
  end

  test "IL-18: a signed-in person who opens the page is sent home; a POST is refused, a student told why" do
    sign_in_as create_teacher

    get new_student_registration_path
    assert_redirected_to teacher_home_path

    register
    assert_response :forbidden
    assert_not Orm::User.exists?(contact: "0701020304")

    sign_out
    sign_in_as create_student(classroom: create_classroom(school: @school))

    get new_student_registration_path
    assert_redirected_to student_home_path

    register
    assert_response :forbidden
    assert_select "[role=alert]", text: I18n.t("#{ERRORS}.base.already_enrolled")
    assert_not Orm::User.exists?(contact: "0701020304")
  end

  test "IL-23, CA-B4: an eleventh sign-up in a minute from the same address receives 429 in the form, no account" do
    10.times { register(pin_confirmation: "1357") }

    register

    assert_response :too_many_requests
    assert_select "form#student-registration-form #signup-rate-limited[role=alert]", text: I18n.t("#{FORM}.rate_limited")
    # UDR §3.1 : en 429 aussi, la page garde sa carte de bienvenue au-dessus du formulaire.
    assert_select "#signup-welcome ~ form#student-registration-form", 1
    assert_select "turbo-frame#picker_classrooms input[checked][value='#{@classroom.public_id}']"
    assert_not Orm::User.exists?(contact: "0701020304")

    get new_student_registration_path
    assert_response :success
  end

  # ADR-0085 §4.6, kept next to the shared counter: the sign-up alone is limited to 5 a minute and per address.
  test "ADR-0085 §4.6: a sixth valid sign-up by code from the same address receives 429, no account created" do
    code = @classroom.reload.join_code
    5.times do |i|
      post student_registrations_path, params: { student_registration: registration_params(join_code: code, classroom_public_id: nil,
                                                                                             contact: "070102030#{i}") }
      assert_redirected_to student_home_path
      sign_out
    end
    accounts = Orm::User.count

    post student_registrations_path, params: { student_registration: registration_params(join_code: code, classroom_public_id: nil,
                                                                                           contact: "0701020309") }

    assert_response :too_many_requests
    assert_select "#signup-rate-limited[role=alert]", text: I18n.t("#{FORM}.rate_limited")
    assert_equal accounts, Orm::User.count
    assert_not Orm::User.exists?(contact: "0701020309")
  end

  test "IL-23: past the limit, a valid code does not show the class recap" do
    code = @classroom.reload.join_code
    10.times { register(join_code: code, pin_confirmation: "1357") }

    register(join_code: code)

    assert_response :too_many_requests
    assert_select "#signup-classroom-recap:not([hidden])", 0
    assert_select "#signup-rate-limited[role=alert]"
    assert_not Orm::User.exists?(contact: "0701020304")
  end

  test "IL-23: past the limit, a valid link keeps its banner" do
    token = @classroom.reload.link_token
    10.times { register(link_token: token, pin_confirmation: "1357") }

    register(link_token: token)

    assert_response :too_many_requests
    assert_equal 2, start_step
    assert_select "#signup-classroom-recap", text: /3e 2/
    assert_select "fieldset[data-step='2'] #signup-rate-limited", text: I18n.t("#{FORM}.rate_limited_link")
  end
end

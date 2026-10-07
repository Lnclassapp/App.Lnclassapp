require "test_helper"

# IL-01, IL-02 (the page), IL-05, IL-06, IL-07, IL-08, IL-09, IL-10, IL-19, IL-20, IL-23 server side (ADR-0083,
# UDR-0079 §3.1 to §3.3): one public sign-up page in three sections (your classroom, you, secret code), no classroom
# code. The classroom is chosen in four chained lists (DRENA, school, level, classroom), or given by a classroom link;
# the student enters it at once, signed in.
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
    { full_name: "KOUASSI Aya Marie", gender: "female", contact: "07 01 02 03 04", pin: "4821", pin_confirmation: "4821",
      drena_public_id: @drena.public_id, school_public_id: @school.public_id, level_slug: @level.slug,
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

  test "IL-02: three sections in order, the DRENA first, the lists empty, the full name — never a classroom code" do
    get new_student_registration_path

    assert_response :success
    assert_select "h2", text: I18n.t("#{PAGE}.title")
    assert_select "p", text: I18n.t("#{PAGE}.subtitle")
    assert_select "form#student-registration-form[action='#{student_registrations_path}'][method=post]" \
                  "[data-controller='classroom--class-picker identity--full-name identity--phone-digits identity--pin-match']" \
                  "[data-classroom--class-picker-schools-url-value='#{drena_schools_path('__drena__', scope: :student_registration)}']" \
                  "[data-classroom--class-picker-levels-url-value='#{school_picker_levels_path('__school__', scope: :student_registration)}']" \
                  "[data-classroom--class-picker-classrooms-url-value='" \
                  "#{school_picker_classrooms_path('__school__', '__level__', scope: :student_registration)}']" do
      assert_equal [ "Ta classe", "Toi", "Code secret" ], css_select("fieldset > legend.uppercase").map { it.text.strip }
      assert_select "select[name='student_registration[drena_public_id]'][data-action='change->classroom--class-picker#loadSchools'] " \
                    "option[value='#{@drena.public_id}']", text: "Abidjan 1"
      %w[picker_schools picker_levels picker_classrooms].each do |frame|
        assert_select "turbo-frame##{frame}.block.transition-opacity[aria-live=polite]", 1, frame
        assert_select "turbo-frame##{frame} *", 0, frame
      end
      assert_select "noscript button[formmethod=get][formaction='#{new_student_registration_path}'][formnovalidate]",
                    text: I18n.t("#{PICKER}.continue")
      assert_select "input[name='student_registration[full_name]'][maxlength='131'][autocomplete=name]" \
                    "[placeholder='#{I18n.t("#{FORM}.full_name_placeholder")}']"
      assert_select "#student_registration_full_name_hint", text: I18n.t("#{FORM}.full_name_hint")
      assert_select "p#full_name_preview[hidden][aria-live=polite]"
      assert_select "details#name-correction:not([open]) input[name='student_registration[last_name]']"
      assert_select "details#name-correction input[name='student_registration[first_name]']"
      assert_select "input[type=radio][name='student_registration[gender]']:not([checked])", count: 2
      assert_select "input[type=tel][name='student_registration[contact]'][maxlength='20'][inputmode=numeric]"
      assert_select "input[type=password][name='student_registration[pin]'][inputmode=numeric][maxlength='4']"
      assert_select "input[type=password][name='student_registration[pin_confirmation]'][data-identity--pin-match-target=confirmation]"
      assert_select "p#pin_match_status[hidden][aria-live=polite]"
      assert_select "template[data-classroom--class-picker-target=loadError]"
      assert_select "button#student-registration-submit[type=submit][data-classroom--class-picker-target=submit]:not([disabled])",
                    text: I18n.t("#{FORM}.submit")
      assert_select "input[name='student_registration[link_token]']", 0
    end
    assert_select "[name*=code], [name*=role]", 0
    assert_select "#classroom-preview, #classroom-link-invalid, #other-classroom", 0
    assert_no_match(/Code de classe/, response.body)
    assert_select "a[href='#{new_session_path}']", text: I18n.t("#{PAGE}.sign_in")
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
    assert_select "turbo-frame#picker_levels select[name='student_registration[level_slug]']" \
                  "[data-action='change->classroom--class-picker#loadClassrooms'] option[value='#{@level.slug}']", text: "3ème"
    assert_select "turbo-frame#picker_classrooms *", 0

    get new_student_registration_path,
        params: { student_registration: registration_params(classroom_public_id: nil, pin: "4821") }

    assert_select "turbo-frame#picker_levels option[selected][value='#{@level.slug}']"
    assert_select "turbo-frame#picker_classrooms fieldset legend", text: /\A\s*#{I18n.t("#{PICKER}.classroom")}/
    assert_select "turbo-frame#picker_classrooms input[type=radio][name='student_registration[classroom_public_id]']" \
                  "[value='#{@classroom.public_id}']:not([checked])"
    assert_select "input[name='student_registration[full_name]'][value='KOUASSI Aya Marie']"
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
    assert_select "turbo-frame#picker_levels select", 0

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

  test "IL-20 (IE-04): the name and first names corrected by hand prevail" do
    register(full_name: "KONÉ OUATTARA Awa", last_name: "KONÉ OUATTARA", first_name: "Awa")

    assert_redirected_to student_home_path
    assert_equal [ "KONÉ OUATTARA", "Awa" ], [ new_student.last_name, new_student.first_name ]
  end

  test "IL-20 (IE-05): a one-word name is refused in 422 under the full name, the correction stays closed" do
    register(full_name: "Kouassi")

    assert_refused :full_name, I18n.t("#{ERRORS}.full_name.single_word")
    assert_equal "Saisis ton nom et tes prénoms.", I18n.t("#{ERRORS}.full_name.single_word")
    assert_select "input[name='student_registration[full_name]'][value='Kouassi'][aria-invalid=true]"
    assert_select "details#name-correction:not([open])"
  end

  test "UDR-0079 §3.2: an error on a corrected name opens the correction, the entries kept" do
    register(last_name: "Kouassi", first_name: "Aya 2")

    assert_refused :first_name, I18n.t("#{ERRORS}.first_name.invalid")
    assert_select "details#name-correction[open] input[name='student_registration[first_name]'][value='Aya 2']"
  end

  test "IL-20 (IE-17, IE-19): different codes are refused in 422, the entries and the four choices kept, never the PINs" do
    register(contact: "+225 07 01 02 03 04", pin_confirmation: "1357")

    assert_refused :pin_confirmation, I18n.t("#{ERRORS}.pin_confirmation.confirmation")
    assert_select "input[name='student_registration[contact]'][value='+225 07 01 02 03 04']"
    assert_select "input[name='student_registration[full_name]'][value='KOUASSI Aya Marie']"
    assert_select "input[name='student_registration[gender]'][value=female][checked]"
    assert_select "input[name='student_registration[pin]'][value]", count: 0
    assert_select "select[name='student_registration[drena_public_id]'] option[selected][value='#{@drena.public_id}']"
    assert_select "turbo-frame#picker_schools option[selected][value='#{@school.public_id}']"
    assert_select "turbo-frame#picker_levels option[selected][value='#{@level.slug}']"
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
    assert_select "form#student-registration-form > [role=alert]", text: I18n.t("#{ERRORS}.base.classroom_full")
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
    assert_select "#classroom-preview", text: /3e 2 — Lycée Moderne de Cocody/
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
    assert_select "form#student-registration-form > #classroom-link-invalid[role=alert]", text: I18n.t("#{FORM}.link_invalid")
    assert_select "select[name='student_registration[drena_public_id]']"
    assert_select "input[name='student_registration[link_token]'], #classroom-preview", 0
  end

  test "IL-09: the standard page, opened from an invalid link, carries the alert once" do
    get join_classroom_path("cccccccccccc")
    follow_redirect!

    assert_select "#classroom-link-invalid[role=alert]", text: "Ce lien n'est plus valable. Choisis ta classe."

    get new_student_registration_path

    assert_select "#classroom-link-invalid", 0
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

  test "IL-23: a sixth sign-up in a minute from the same address receives 429 in the form, no account" do
    5.times { register(pin_confirmation: "1357") }

    register

    assert_response :too_many_requests
    assert_select "form#student-registration-form [role=alert]", text: I18n.t("errors.codes.rate_limited")
    assert_select "turbo-frame#picker_classrooms input[checked][value='#{@classroom.public_id}']"
    assert_not Orm::User.exists?(contact: "0701020304")

    get new_student_registration_path
    assert_response :success
  end

  test "IL-23: past the limit, a valid link keeps its banner" do
    token = @classroom.reload.link_token
    5.times { register(link_token: token, pin_confirmation: "1357") }

    register(link_token: token)

    assert_response :too_many_requests
    assert_select "#classroom-preview", text: /3e 2/
  end
end

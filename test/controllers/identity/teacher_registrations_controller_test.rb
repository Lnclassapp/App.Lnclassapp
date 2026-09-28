require "test_helper"

# ID-03, TR-cadre-1, CE-01 to CE-05 (ADR-0030, ADR-0050, ADR-0057, UDR-0024, UDR-0044): a visitor signs up as a teacher
# with the code of their school, typed or carried by the link /e/<code>; the school is found by its code, never chosen in
# a list; every refused code reads the same; the role is always teacher; the new teacher lands on the class selection.
class Identity::TeacherRegistrationsControllerTest < ActionDispatch::IntegrationTest
  ERRORS = "activemodel.errors.models.dtos/identity/teacher_registration_input.attributes".freeze
  PAGE = "identity.teacher_registrations.new".freeze

  setup do
    @drena = create_drena(name: "Abidjan 1")
    @school = create_school(drena: @drena, name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
    @material = create_material(name: "SVT", shortname: "SVT")
  end

  test "CE-01: the form asks for the person, the number, the PIN twice, the school code and the subject — no DRENA, no list" do
    get new_teacher_registration_path

    assert_response :success
    assert_select "h2", text: I18n.t("#{PAGE}.title")
    %w[last_name first_name contact].each { assert_select "input[name='teacher_registration[#{it}]']" }
    assert_select "input[type=radio][name='teacher_registration[gender]']", count: 2
    assert_select "input[type=password][name='teacher_registration[pin]'][inputmode=numeric][maxlength='4']"
    assert_select "input[type=password][name='teacher_registration[pin_confirmation]']"
    assert_select "input[type=text][name='teacher_registration[school_code]'][autocomplete=off][autocapitalize=characters]"
    assert_select "label[for=teacher_registration_school_code]",
                  text: /#{I18n.t("activemodel.attributes.dtos/identity/teacher_registration_input.school_code")}/
    assert_select "select[name='teacher_registration[material_slug]'] option[value='#{@material.slug}']", text: "SVT"
    assert_select "select[name='teacher_registration[drena_public_id]'], [name='teacher_registration[school_public_id]']", 0
    assert_select "form#teacher-signup-drena, turbo-frame#schools, [data-controller~='school--drena-schools']", 0
    assert_select "#school-preview", 0
    assert_select "input[name*=role]", count: 0
    assert_select "a[href='#{new_session_path}']"
  end

  test "a signed-in person who opens the sign-up page or a code link is sent home" do
    sign_in_as create_teacher

    get new_teacher_registration_path
    assert_redirected_to teacher_home_path

    get school_code_signup_path("k7m4qz")
    assert_redirected_to teacher_home_path
  end

  test "CE-01: a complete sign-up with the code typed anyhow creates the teacher attached to its school, signed in" do
    post teacher_registrations_path, params: { teacher_registration: registration_params(school_code: " k7m 4QZ ") }

    assert_redirected_to teacher_classrooms_path
    assert_response :see_other
    assert_equal I18n.t("identity.teacher_registrations.create.welcome"), flash[:notice]
    teacher = Orm::User.find_by!(contact: "0501020304")
    assert_equal [ "teacher", nil, "Kouassi", "Aya Marie", "female" ],
                 [ teacher.role, teacher.team_role, teacher.last_name, teacher.first_name, teacher.gender ]
    profile = Orm::TeacherProfile.find_by!(user: teacher)
    assert_equal [ @material.id, nil ], [ profile.material_id, profile.onboarding_completed_at ]
    assert_equal [ [ @school.id, true ] ], Orm::TeacherSchool.where(teacher:).pluck(:school_id, :primary)
    assert Orm::User.authenticate_by(contact: "0501020304", pin: "4821")
    assert_equal 1, Orm::Session.where(user: teacher).count
    assert cookies[:session_token].present?

    get new_teacher_registration_path

    assert_response :redirect, "la session est ouverte"
  end

  test "CE-02: the link /e/<code> shows the school and its DRENA, carries the code hidden, and keeps a way out" do
    get school_code_signup_path("K7M-4qz")

    assert_response :success
    assert_select "#school-preview", text: /Lycée Classique d'Abidjan/
    assert_select "#school-preview", text: /Abidjan 1/
    assert_select "form#teacher-registration-form[action='#{teacher_registrations_path}'] " \
                  "input[type=hidden][name='teacher_registration[school_code]'][value='K7M-4QZ']"
    assert_select "input[type=text][name='teacher_registration[school_code]']", 0
    assert_select "a#other-school-code[href='#{new_teacher_registration_path}']"
    assert_not_includes response.body, @school.public_id
  end

  test "CE-02: signing up from the link attaches the teacher to the school of the link" do
    get school_code_signup_path("k7m4qz")
    post teacher_registrations_path, params: { teacher_registration: registration_params(school_code: "K7M-4QZ") }

    assert_redirected_to teacher_classrooms_path
    assert_equal [ @school.id ], Orm::TeacherSchool.where(teacher: Orm::User.find_by!(contact: "0501020304")).pluck(:school_id)
  end

  test "CE-03: an unknown, replaced, inactive or draft code is refused in 422 with the same message, no account" do
    create_school(drena: @drena, name: "Lycée fermé", status: "inactive", school_code: "abc234")
    create_school(drena: @drena, name: "Lycée en brouillon", status: "draft", school_code: "xyz789")

    %w[zzz999 abc234 xyz789].each do |school_code|
      post teacher_registrations_path, params: { teacher_registration: registration_params(school_code:) }

      assert_refused :school_code, I18n.t("#{ERRORS}.school_code.inclusion")
      assert_select "input[type=text][name='teacher_registration[school_code]'][value='#{school_code}']"
      assert_select "#school-preview", 0
    end
  end

  test "CE-03: the link of an unknown, inactive or draft code answers 404 with the same card, never the school" do
    create_school(drena: @drena, name: "Lycée fermé", status: "inactive", school_code: "abc234")
    create_school(drena: @drena, name: "Lycée en brouillon", status: "draft", school_code: "xyz789")

    %w[zzz999 abc234 xyz789 kfm37].each do |code|
      get school_code_signup_path(code)

      assert_response :not_found
      assert_select "#invalid-school-code h2", text: I18n.t("#{PAGE}.invalid_code.title")
      assert_select "#invalid-school-code a[href='#{new_teacher_registration_path}']", text: I18n.t("#{PAGE}.invalid_code.other_code")
      assert_select "form#teacher-registration-form", 0
      assert_no_match(/Lycée fermé|Lycée en brouillon/, response.body)
    end
  end

  test "CE-04: a blank code, a malformed one and a classroom code each have their message, in 422" do
    { "" => :blank, "k7m4q" => :invalid, "KFM 37" => :classroom_code }.each do |school_code, kind|
      post teacher_registrations_path, params: { teacher_registration: registration_params(school_code:) }

      assert_refused :school_code, I18n.t("#{ERRORS}.school_code.#{kind}")
    end
  end

  test "CE-04: a school chosen by hand (old form) is ignored: without a code, no account" do
    post teacher_registrations_path,
         params: { teacher_registration: registration_params(school_code: nil, drena_public_id: @drena.public_id,
                                                             school_public_id: @school.public_id) }

    assert_refused :school_code, I18n.t("#{ERRORS}.school_code.blank")
  end

  test "an error after a good code shows the school instead of the field, the entries are kept, the PINs are not" do
    post teacher_registrations_path,
         params: { teacher_registration: registration_params(pin_confirmation: "1357", school_code: "k7m 4qz") }

    assert_refused :pin_confirmation, I18n.t("#{ERRORS}.pin_confirmation.confirmation")
    assert_select "#school-preview", text: /Lycée Classique d'Abidjan/
    assert_select "input[type=hidden][name='teacher_registration[school_code]'][value='K7M-4QZ']"
    assert_select "input[name='teacher_registration[last_name]'][value='Kouassi']"
    assert_select "input[name='teacher_registration[contact]'][value='05 01 02 03 04']"
    assert_select "input[name='teacher_registration[pin]'][value]", count: 0
  end

  test "TR-cadre-1: a role added by hand is ignored, the account is a teacher and no team account exists" do
    post teacher_registrations_path, params: { teacher_registration: registration_params(role: "team", team_role: "admin") }

    assert_redirected_to teacher_classrooms_path
    assert_equal [ "teacher", nil ], Orm::User.where(contact: "0501020304").pick(:role, :team_role)
    assert_not Orm::User.exists?(role: %w[team school_admin])
  end

  test "a number already used is refused in 422 with its message" do
    create_user(role: "student", contact: "0501020304")

    post teacher_registrations_path, params: { teacher_registration: registration_params }

    assert_response :unprocessable_entity
    assert_select "#teacher_registration_contact_error", text: I18n.t("#{ERRORS}.contact.taken")
    assert_equal 1, Orm::User.count
  end

  test "an unknown subject and an invalid number are refused in 422" do
    post teacher_registrations_path, params: { teacher_registration: registration_params(material_slug: "latin") }

    assert_refused :material_slug, I18n.t("#{ERRORS}.material_slug.inclusion")

    post teacher_registrations_path, params: { teacher_registration: registration_params(contact: "0801020304") }

    assert_refused :contact, I18n.t("#{ERRORS}.contact.invalid")
  end

  test "a signed-in person who posts the form is refused" do
    sign_in_as create_teacher

    post teacher_registrations_path, params: { teacher_registration: registration_params }

    assert_response :forbidden
    assert_not Orm::User.exists?(contact: "0501020304")
  end

  test "a sixth attempt in a minute receives 429 in the form" do
    6.times { post teacher_registrations_path, params: { teacher_registration: registration_params(pin_confirmation: "1357") } }

    assert_response :too_many_requests
    assert_select "[role=alert]", text: I18n.t("errors.codes.rate_limited")
  end

  test "CE-05: the eleventh code link opened in a minute from the same address receives 429, without the school" do
    10.times { |index| get school_code_signup_path(index.even? ? "k7m4qz" : "zzz999") }

    get school_code_signup_path("k7m4qz")

    assert_response :too_many_requests
    assert_select "[role=alert]", text: /#{Regexp.escape(I18n.t('errors.codes.rate_limited'))}/
    assert_not_includes response.body, "Lycée Classique d'Abidjan"
    assert_select "form#teacher-registration-form", 0
  end

  test "CE-05: the links have their own count: the sign-up form is still served, and the post still accepted" do
    10.times { get school_code_signup_path("zzz999") }

    get new_teacher_registration_path
    assert_response :success

    post teacher_registrations_path, params: { teacher_registration: registration_params }
    assert_redirected_to teacher_classrooms_path
  end

  private

  def registration_params(**overrides)
    { last_name: "Kouassi", first_name: "Aya Marie", gender: "female", contact: "05 01 02 03 04", pin: "4821",
      pin_confirmation: "4821", school_code: "K7M-4QZ", material_slug: @material.slug, **overrides }
  end

  def assert_refused(attribute, message)
    assert_response :unprocessable_entity
    assert_select "#teacher_registration_#{attribute}_error", text: message
    assert_not Orm::User.exists?(contact: "0501020304")
  end
end

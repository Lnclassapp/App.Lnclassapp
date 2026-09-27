require "test_helper"

# ID-03, SC-27, TR-cadre-1 (ADR-0030, ADR-0050, UDR-0024): a visitor signs up as a teacher, with a primary school
# chosen inside the chosen DRENA; the role is always teacher; the new teacher lands on the class selection.
class Identity::TeacherRegistrationsControllerTest < ActionDispatch::IntegrationTest
  ERRORS = "activemodel.errors.models.dtos/identity/teacher_registration_input.attributes".freeze

  setup do
    @drena = create_drena(name: "Abidjan 1")
    @school = create_school(drena: @drena, name: "Lycée Classique d'Abidjan")
    @material = create_material(name: "SVT", shortname: "SVT")
  end

  test "the form asks for the person, the number, the PIN twice, the DRENA, the school and the subject" do
    closed = create_school(drena: @drena, name: "Lycée fermé", status: "inactive")

    get new_teacher_registration_path

    assert_response :success
    assert_select "h2", text: I18n.t("identity.teacher_registrations.new.title")
    %w[last_name first_name contact].each { assert_select "input[name='teacher_registration[#{it}]']" }
    assert_select "input[type=radio][name='teacher_registration[gender]']", count: 2
    assert_select "input[type=password][name='teacher_registration[pin]'][inputmode=numeric][maxlength='4']"
    assert_select "input[type=password][name='teacher_registration[pin_confirmation]']"
    assert_select "select[name='teacher_registration[drena_public_id]'][form='teacher-signup-drena'] option[value='#{@drena.public_id}']",
                  text: "Abidjan 1"
    assert_select "select[name='teacher_registration[material_slug]'] option[value='#{@material.slug}']", text: "SVT"
    assert_select "turbo-frame#schools select[name='teacher_registration[school_public_id]'][disabled]"
    assert_select "turbo-frame#schools option[value='#{closed.public_id}']", count: 0
    assert_select "input[name*=role]", count: 0
    assert_select "a[href='#{new_session_path}']"
  end

  test "without JavaScript, the DRENA sent in GET lists its active schools in the frame" do
    create_school(drena: @drena, name: "Lycée fermé", status: "inactive")
    create_school(drena: @drena, name: "Collège Voltaire")

    get new_teacher_registration_path, params: { teacher_registration: { drena_public_id: @drena.public_id } }

    assert_response :success
    assert_select "form#teacher-signup-drena[method=get][action='#{new_teacher_registration_path}']"
    assert_match %r{<noscript>\s*<button[^>]+form="teacher-signup-drena"}, response.body
    assert_select "select[name='teacher_registration[drena_public_id]'] option[selected][value='#{@drena.public_id}']"
    assert_select "turbo-frame#schools input[type=hidden][name='teacher_registration[drena_public_id]'][value='#{@drena.public_id}']"
    assert_equal [ "Collège Voltaire", "Lycée Classique d'Abidjan" ],
                 css_select("turbo-frame#schools select option[value!='']").map(&:text)
  end

  test "a signed-in person who opens the sign-up page is sent home" do
    sign_in_as create_teacher

    get new_teacher_registration_path

    assert_redirected_to teacher_home_path
  end

  test "a complete sign-up creates the teacher, attaches the school and lands on the class selection, signed in" do
    post teacher_registrations_path, params: { teacher_registration: registration_params }

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

  test "TR-cadre-1: a role added by hand is ignored, the account is a teacher and no team account exists" do
    post teacher_registrations_path, params: { teacher_registration: registration_params(role: "team", team_role: "admin") }

    assert_redirected_to teacher_classrooms_path
    assert_equal [ "teacher", nil ], Orm::User.where(contact: "0501020304").pick(:role, :team_role)
    assert_not Orm::User.exists?(role: %w[team school_admin])
  end

  test "a school of another DRENA is refused in 422 and no account is created" do
    other = create_school(drena: create_drena(name: "Abidjan 2"), name: "Lycée d'Abidjan 2")

    post teacher_registrations_path, params: { teacher_registration: registration_params(school_public_id: other.public_id) }

    assert_refused :school_public_id, I18n.t("#{ERRORS}.school_public_id.inclusion")
  end

  test "an inactive school is refused in 422 and no account is created" do
    closed = create_school(drena: @drena, name: "Lycée fermé", status: "inactive")

    post teacher_registrations_path, params: { teacher_registration: registration_params(school_public_id: closed.public_id) }

    assert_refused :school_public_id, I18n.t("#{ERRORS}.school_public_id.inclusion")
    assert_select "turbo-frame#schools option[value='#{@school.public_id}']"
  end

  test "an unconfirmed PIN is refused under its confirmation, the entries are kept, the PINs are not" do
    post teacher_registrations_path, params: { teacher_registration: registration_params(pin_confirmation: "1357") }

    assert_refused :pin_confirmation, I18n.t("#{ERRORS}.pin_confirmation.confirmation")
    assert_select "input[name='teacher_registration[last_name]'][value='Kouassi']"
    assert_select "input[name='teacher_registration[contact]'][value='05 01 02 03 04']"
    assert_select "input[name='teacher_registration[pin]'][value]", count: 0
    assert_select "select[name='teacher_registration[school_public_id]'] option[selected][value='#{@school.public_id}']"
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

  private

  def registration_params(**overrides)
    { last_name: "Kouassi", first_name: "Aya Marie", gender: "female", contact: "05 01 02 03 04", pin: "4821",
      pin_confirmation: "4821", drena_public_id: @drena.public_id, school_public_id: @school.public_id,
      material_slug: @material.slug, **overrides }
  end

  def assert_refused(attribute, message)
    assert_response :unprocessable_entity
    assert_select "#teacher_registration_#{attribute}_error", text: message
    assert_not Orm::User.exists?(contact: "0501020304")
  end
end

require "test_helper"

# ID-01 to ID-06 (ADR-0077, UDR-0070 §3.1): a visitor registers as the direction of an active school with its code; the
# role is always school_admin; at most 3 active directions by the code; the new direction lands on « Travail des élèves ».
class Identity::SchoolStaffRegistrationsControllerTest < ActionDispatch::IntegrationTest
  ERRORS = "activemodel.errors.models.dtos/identity/school_staff_registration_input.attributes".freeze
  PAGE = "identity.school_staff_registrations.new".freeze
  FORM = "identity.school_staff_registrations.form".freeze

  setup do
    @drena = create_drena(name: "Abidjan 1")
    @school = create_school(drena: @drena, name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
  end

  test "UDR-0070 §3.1: the form asks for the person, the number, the school code and the PIN twice — no subject, no role" do
    get new_school_staff_registration_path

    assert_response :success
    assert_select "title", text: /#{I18n.t("#{PAGE}.page_title")}/
    assert_select "h1", text: I18n.t("#{PAGE}.welcome")
    assert_select "h2", text: I18n.t("#{PAGE}.title")
    assert_select "form#school-staff-registration-form[action='#{school_staff_registrations_path}']" do
      %w[last_name first_name].each { assert_select "input[name='school_staff_registration[#{it}]']" }
      assert_select "input[type=tel][name='school_staff_registration[contact]']"
      assert_select "input[type=radio][name='school_staff_registration[gender]']", count: 2
      assert_select "input[type=text][name='school_staff_registration[school_code]'][maxlength='12'][placeholder='K7M-4QZ']"
      assert_select "input[type=password][name='school_staff_registration[pin]'][inputmode=numeric][maxlength='4']"
      assert_select "input[type=password][name='school_staff_registration[pin_confirmation]']"
      assert_select "fieldset > legend", text: I18n.t("#{FORM}.school")
      assert_select "button[type=submit][data-turbo-submits-with='#{I18n.t("#{FORM}.submitting")}']", text: I18n.t("#{FORM}.submit")
    end
    assert_select "[name*=material], [name*=role]", 0
    assert_select "a[href='#{new_session_path}']", text: I18n.t("#{PAGE}.sign_in")
    assert_select "a[href='#{root_path}'][aria-label='#{I18n.t("#{PAGE}.logo_home")}']"
  end

  test "a signed-in person who opens the page is sent home" do
    sign_in_as create_school_admin(school: @school)

    get new_school_staff_registration_path

    assert_redirected_to school_admin_classrooms_path
  end

  test "ID-01: the code typed anyhow creates a school_admin attached by the code, signed in, sent to the student work" do
    post school_staff_registrations_path, params: { school_staff_registration: registration_params(school_code: " k7m 4QZ ") }

    assert_redirected_to school_admin_classrooms_path
    assert_response :see_other
    assert_equal I18n.t("identity.school_staff_registrations.create.created"), flash[:notice]
    admin = Orm::User.find_by!(contact: "0701020304")
    assert_equal [ "school_admin", nil, "Kouassi", "Aya Marie", "female" ],
                 [ admin.role, admin.team_role, admin.last_name, admin.first_name, admin.gender ]
    assert_equal [ [ @school.id, "code", nil, nil ] ],
                 Orm::SchoolStaff.where(user: admin).pluck(:school_id, :joined_via, :archived_at, :invited_by_id)
    assert Orm::User.authenticate_by(contact: "0701020304", pin: "4821")
    assert_equal 1, Orm::Session.where(user: admin).count
    assert cookies[:session_token].present?
    event = Orm::AuditEvent.find_by!(action: "school_staff.registered")
    assert_equal [ admin.id, "User", admin.id, { "school_id" => @school.id, "joined_via" => "code" } ],
                 [ event.actor_id, event.subject_type, event.subject_id, event.metadata ]

    follow_redirect!

    assert_response :success
  end

  test "a role added by hand is ignored: the account is a school_admin and no team account exists" do
    post school_staff_registrations_path,
         params: { school_staff_registration: registration_params(role: "team", team_role: "admin", material_slug: "svt") }

    assert_redirected_to school_admin_classrooms_path
    assert_equal [ "school_admin", nil ], Orm::User.where(contact: "0701020304").pick(:role, :team_role)
    assert_not Orm::User.exists?(role: %w[team teacher])
  end

  test "ID-02: with 3 active directions by the code and 1 invited, the fourth is refused in 422, no account" do
    3.times { create_school_admin(school: @school, joined_via: "code") }
    create_school_admin(school: @school, joined_via: "invitation")

    assert_no_difference -> { Orm::User.count } do
      post school_staff_registrations_path, params: { school_staff_registration: registration_params }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: I18n.t("#{ERRORS}.base.cap_reached")
    assert_not Orm::AuditEvent.exists?(action: "school_staff.registered")
    assert_nil cookies[:session_token].presence
  end

  test "ID-03: 2 active by the code, 1 archived by the code and 4 invited: the account is created" do
    2.times { create_school_admin(school: @school, joined_via: "code") }
    create_school_admin(school: @school, joined_via: "code", archived_at: 1.day.ago)
    4.times { create_school_admin(school: @school, joined_via: "invitation") }

    post school_staff_registrations_path, params: { school_staff_registration: registration_params }

    assert_redirected_to school_admin_classrooms_path
    assert_equal 3, Orm::SchoolStaff.where(school: @school, joined_via: "code", archived_at: nil).count
  end

  test "ID-05: an unknown, draft or inactive code is refused in 422 with the same message, no account" do
    create_school(drena: @drena, status: "draft", school_code: "xyz789")
    create_school(drena: @drena, status: "inactive", school_code: "abc234")

    %w[XYZ-789 ABC-234 ZZZ-999].each do |school_code|
      post school_staff_registrations_path, params: { school_staff_registration: registration_params(school_code:) }

      assert_refused :school_code, I18n.t("#{ERRORS}.school_code.inclusion")
    end
  end

  test "a blank code and a malformed one (an old classroom code included) each have their message, in 422" do
    { "" => :blank, "k7m4q" => :invalid, "KFM 37" => :invalid }.each do |school_code, kind|
      post school_staff_registrations_path, params: { school_staff_registration: registration_params(school_code:) }

      assert_refused :school_code, I18n.t("#{ERRORS}.school_code.#{kind}")
    end
  end

  test "ID-06: a number already linked to a teacher account is refused in 422 with its message" do
    create_teacher(contact: "0701020304")

    assert_no_difference -> { Orm::User.count } do
      post school_staff_registrations_path, params: { school_staff_registration: registration_params }
    end

    assert_response :unprocessable_entity
    assert_select "#school_staff_registration_contact_error", text: I18n.t("#{ERRORS}.contact.taken")
    assert_not Orm::SchoolStaff.exists?(school: @school)
  end

  test "an error keeps the entries as typed, not the PINs" do
    post school_staff_registrations_path,
         params: { school_staff_registration: registration_params(school_code: "k7m 4qz", pin_confirmation: "1357") }

    assert_refused :pin_confirmation, I18n.t("#{ERRORS}.pin_confirmation.confirmation")
    assert_select "input[name='school_staff_registration[last_name]'][value='Kouassi']"
    assert_select "input[name='school_staff_registration[contact]'][value='07 01 02 03 04']"
    assert_select "input[name='school_staff_registration[school_code]'][value='k7m 4qz']"
    assert_select "input[name='school_staff_registration[pin]']:not([value])"
  end

  test "a signed-in person who posts the form is refused" do
    sign_in_as create_teacher

    post school_staff_registrations_path, params: { school_staff_registration: registration_params }

    assert_response :forbidden
    assert_not Orm::User.exists?(contact: "0701020304")
  end

  private

  def registration_params(**overrides)
    { last_name: "Kouassi", first_name: "Aya Marie", gender: "female", contact: "07 01 02 03 04", pin: "4821",
      pin_confirmation: "4821", school_code: "K7M-4QZ", **overrides }
  end

  def assert_refused(attribute, message)
    assert_response :unprocessable_entity
    assert_select "#school_staff_registration_#{attribute}_error", text: message
    assert_not Orm::User.exists?(contact: "0701020304")
  end
end

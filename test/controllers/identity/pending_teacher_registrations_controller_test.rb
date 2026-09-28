require "test_helper"

# CP-11, CP-14 (ADR-0063, UDR-0050): « Mon établissement n'a pas encore de code Lnclass ». The school is designated by its
# national code, or chosen in the list of its DRENA (UDR-0024); the account is created waiting for a validation.
class Identity::PendingTeacherRegistrationsControllerTest < ActionDispatch::IntegrationTest
  ERRORS = "activemodel.errors.models.dtos/identity/pending_teacher_registration_input.attributes".freeze
  PAGE = "identity.teacher_registrations.new".freeze

  setup do
    @drena = create_drena(name: "Abidjan 1")
    @school = create_school(drena: @drena, name: "Lycée Classique d'Abidjan", national_code: "012345")
    @material = create_material(name: "SVT", shortname: "SVT")
  end

  def registration_params(**overrides)
    { last_name: "Koné", first_name: "Awa", gender: "female", contact: "05 01 02 03 04", pin: "4821", pin_confirmation: "4821",
      material_slug: @material.slug, **overrides }
  end

  test "the sign-up by code leads to the sign-up without code" do
    get new_teacher_registration_path

    assert_select "a#no-school-code[href='#{new_pending_teacher_registration_path}']",
                  text: I18n.t("identity.teacher_registrations.form.no_school_code")
  end

  test "CP-11: the form asks the national code or the DRENA then the school — never the school code" do
    get new_pending_teacher_registration_path

    assert_response :success
    assert_select "h2", text: I18n.t("#{PAGE}.pending_title")
    assert_select "form#pending-teacher-registration-form[action='#{pending_teacher_registrations_path}']" do
      assert_select "input[name='teacher_registration[national_code]'][inputmode=numeric]"
      assert_select "input[name='teacher_registration[school_code]']", 0
      assert_select "turbo-frame#schools select[name='teacher_registration[school_public_id]'][disabled]"
    end
    assert_select "select[name='teacher_registration[drena_public_id]'][form=teacher-signup-drena] option[value='#{@drena.public_id}']"
  end

  test "without JavaScript, the DRENA chosen lists its active schools" do
    get new_pending_teacher_registration_path, params: { teacher_registration: { drena_public_id: @drena.public_id } }

    assert_select "turbo-frame#schools select[name='teacher_registration[school_public_id]'] option[value='#{@school.public_id}']"
  end

  test "CP-11: by the national code, the account is created without school, waiting, signed in" do
    post pending_teacher_registrations_path, params: { teacher_registration: registration_params(national_code: "012 345") }

    assert_redirected_to pending_account_path
    assert_equal I18n.t("identity.pending_teacher_registrations.create.done"), flash[:notice]
    teacher = Orm::User.find_by!(contact: "0501020304")
    assert_equal [ "teacher", 0 ], [ teacher.role, Orm::TeacherSchool.where(teacher:).count ]
    assert_equal [ [ @school.id, "pending" ] ], Orm::SchoolJoinRequest.where(teacher:).pluck(:school_id, :status)
    assert cookies[:session_token].present?
    follow_redirect!
    assert_select "#pending_account", text: /Lycée Classique d'Abidjan/
  end

  test "CP-11: by the school chosen in its DRENA" do
    post pending_teacher_registrations_path,
         params: { teacher_registration: registration_params(drena_public_id: @drena.public_id, school_public_id: @school.public_id) }

    assert_redirected_to pending_account_path
    assert_equal [ @school.id ], Orm::SchoolJoinRequest.pluck(:school_id)
  end

  test "an unknown national code, or none at all, comes back in 422 with its message; the list keeps its DRENA" do
    post pending_teacher_registrations_path, params: { teacher_registration: registration_params(national_code: "999999") }

    assert_response :unprocessable_entity
    assert_select "#teacher_registration_national_code_error", text: I18n.t("#{ERRORS}.national_code.inclusion")

    post pending_teacher_registrations_path, params: { teacher_registration: registration_params(drena_public_id: @drena.public_id) }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /#{I18n.t("activemodel.errors.models.dtos/identity/pending_teacher_registration_input.attributes.base.school_missing")}/
    assert_select "turbo-frame#schools option[value='#{@school.public_id}']"
    assert_equal 0, Orm::User.count
  end

  test "CP-14: a school with 5 pending requests refuses a sixth, with a named message" do
    5.times { create_join_request(school: @school) }

    post pending_teacher_registrations_path, params: { teacher_registration: registration_params(national_code: "012345") }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /#{I18n.t("#{ERRORS}.base.too_many_pending")}/
    assert_not Orm::User.exists?(contact: "0501020304")
  end

  test "CP-14: more than 5 sign-ups per minute from one address: 429" do
    5.times do |attempt|
      post pending_teacher_registrations_path, params: { teacher_registration: registration_params(national_code: "999999") }
      assert_response :unprocessable_entity, attempt
    end
    post pending_teacher_registrations_path, params: { teacher_registration: registration_params(national_code: "012345") }

    assert_response :too_many_requests
    assert_equal 0, Orm::User.count
  end

  test "a signed-in person is sent home" do
    sign_in_as create_teacher

    get new_pending_teacher_registration_path

    assert_redirected_to teacher_home_path
  end
end

require "test_helper"

# ID-07 (UDR-0070 §3.0, §3.1): ten registrations a minute from the same address; the eleventh receives 429 and the
# « Trop de tentatives » state, without the form, and creates nothing.
class Identity::SchoolStaffRegistrationRateLimitTest < ActionDispatch::IntegrationTest
  PAGE = "identity.school_staff_registrations.new".freeze

  setup { create_school(school_code: "k7m4qz") }

  test "ID-07: the eleventh registration in a minute from the same address receives 429 « Trop de tentatives »" do
    10.times do
      post school_staff_registrations_path, params: { school_staff_registration: registration_params(pin_confirmation: "1357") }

      assert_response :unprocessable_entity
    end

    post school_staff_registrations_path, params: { school_staff_registration: registration_params }

    assert_response :too_many_requests
    assert_select "[role=alert] p", text: I18n.t("#{PAGE}.rate_limited_title")
    assert_select "[role=alert]", text: /#{Regexp.escape(I18n.t('errors.codes.rate_limited'))}/
    assert_select "form#school-staff-registration-form", 0
    assert_not Orm::User.exists?(contact: "0701020304")
  end

  test "another address still registers" do
    10.times { post school_staff_registrations_path, params: { school_staff_registration: registration_params(pin_confirmation: "1357") } }

    post school_staff_registrations_path, params: { school_staff_registration: registration_params },
                                          env: { "REMOTE_ADDR" => "10.0.0.2" }

    assert_redirected_to school_admin_classrooms_path
  end

  private

  def registration_params(**overrides)
    { last_name: "Kouassi", first_name: "Aya", gender: "female", contact: "07 01 02 03 04", pin: "4821",
      pin_confirmation: "4821", school_code: "K7M-4QZ", **overrides }
  end
end

require "test_helper"

# CE-07, CE-08 (ADR-0057, UDR-0044): the team regenerates a school's code from its page; the old code stops working at
# once, the teachers already attached stay; outside the team, nothing changes. GD-05 (ADR-0071 §4.2): with the policy
# shared with the direction, the team's gesture is unchanged.
class Teams::SchoolCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
    @teacher = create_teacher(school: @school)
  end

  def new_code = @school.reload.school_code

  def staff_params(school_code:)
    { last_name: "Kouassi", first_name: "Aya Marie", gender: "female", contact: "0701020304", pin: "4821",
      pin_confirmation: "4821", school_code: }
  end

  test "CE-07: the regeneration replaces the code, replaces the header and says the new code; the teachers stay" do
    sign_in_as create_team_member

    patch school_code_path(@school.public_id), as: :turbo_stream

    assert_response :success
    assert Entities::School::SchoolCode.valid?(new_code)
    assert_not_equal "k7m4qz", new_code
    display = Entities::School::SchoolCode.display(new_code)
    assert_select "turbo-stream[action=append][target=toasts]",
                  text: /#{Regexp.escape(I18n.t('teams.school_codes.update.done', code: display))}/
    assert_select "turbo-stream[action=replace][target=school_header] template #school_code_value", text: display
    assert_equal [ @school.id ], Orm::TeacherSchool.where(teacher: @teacher).pluck(:school_id)
    assert_not_nil @school.reload.school_code_rotated_at
    assert Orm::AuditEvent.exists?(action: "school.changed", subject_id: @school.id)
  end

  # ADR-0082 §4.5: the code now opens only the direction's sign-up (/school-staff-signup).
  test "CE-07: the old code no longer signs up a direction, the new one does" do
    sign_in_as create_team_member
    patch school_code_path(@school.public_id), as: :turbo_stream
    sign_out

    post school_staff_registrations_path, params: { school_staff_registration: staff_params(school_code: "K7M-4QZ") }
    assert_response :unprocessable_entity
    assert_not Orm::User.exists?(contact: "0701020304")

    post school_staff_registrations_path, params: { school_staff_registration: staff_params(school_code: new_code) }
    assert_redirected_to school_admin_classrooms_path
    assert_equal [ @school.id ], Orm::SchoolStaff.where(user: Orm::User.find_by!(contact: "0701020304")).pluck(:school_id)
  end

  test "without JavaScript, the regeneration comes back to the school's page with a notice" do
    sign_in_as create_team_member

    patch school_code_path(@school.public_id)

    assert_redirected_to school_path(@school.public_id)
    assert_equal I18n.t("teams.school_codes.update.done", code: Entities::School::SchoolCode.display(new_code)), flash[:notice]
  end

  test "CE-08: outside the team, the regeneration is refused and the code does not change" do
    sign_in_as @teacher

    patch school_code_path(@school.public_id), as: :turbo_stream

    assert_response :forbidden
    assert_equal "k7m4qz", new_code
  end

  test "GD-05: the team still regenerates from the school's page, an inactive school's included" do
    @school.update!(status: "inactive")
    sign_in_as create_team_member

    patch school_code_path(@school.public_id), as: :turbo_stream

    assert_response :success
    assert_not_equal "k7m4qz", new_code
  end

  test "GD-05: the team's route stays the team's: the school's own direction is refused, its code unchanged" do
    sign_in_as create_school_admin(school: @school)

    patch school_code_path(@school.public_id), as: :turbo_stream

    assert_response :forbidden
    assert_equal "k7m4qz", new_code
  end

  test "an unknown school answers 404" do
    sign_in_as create_team_member

    patch school_code_path("inconnu"), as: :turbo_stream

    assert_response :not_found
  end
end

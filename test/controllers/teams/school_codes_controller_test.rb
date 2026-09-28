require "test_helper"

# CE-07, CE-08 (ADR-0057, UDR-0044): the team regenerates a school's code from its page; the old code stops working at
# once, the teachers already attached stay; outside the team, nothing changes.
class Teams::SchoolCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
    @teacher = create_teacher(school: @school)
  end

  def new_code = @school.reload.school_code

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

  test "CE-07: the old code no longer opens the sign-up, the new one does" do
    sign_in_as create_team_member
    patch school_code_path(@school.public_id), as: :turbo_stream
    sign_out

    get school_code_signup_path("k7m4qz")
    assert_response :not_found

    get school_code_signup_path(new_code)
    assert_response :success
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

  test "an unknown school answers 404" do
    sign_in_as create_team_member

    patch school_code_path("inconnu"), as: :turbo_stream

    assert_response :not_found
  end
end

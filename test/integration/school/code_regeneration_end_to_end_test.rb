require "test_helper"

# ADR-0096, RM-03, RM-18: from the launch by the admin to the visitor who holds the old code or the old link — the old ones
# are dead (« Code d'établissement invalide », « lien invalide »), the new ones live.
class School::CodeRegenerationEndToEndTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @admin = create_team_member(team_role: "admin")
    @drena = create_drena(name: "Abidjan 1")
    @school = create_school(drena: @drena, name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
    @classroom = create_classroom(school: @school, name: "6e 1")
  end

  def launch(target)
    post code_regenerations_path, params: { code_regeneration: { target:, selection: { school: @school.public_id }, current_year_only: "1" } }
    assert_response :see_other
  end

  def register_direction(school_code)
    post school_staff_registrations_path, params: { school_staff_registration: {
      last_name: "Kouassi", first_name: "Aya Marie", gender: "female", contact: "07 01 02 03 04", pin: "4821",
      pin_confirmation: "4821", school_code:, position: "head"
    } }
  end

  test "RM-03: after the regeneration of the codes, the old code no longer registers a direction and the new one does" do
    sign_in_as @admin
    perform_enqueued_jobs { launch("school_codes") }
    new_code = @school.reload.school_code
    sign_out

    assert_not_equal "k7m4qz", new_code
    register_direction("K7M-4QZ")

    assert_response :unprocessable_entity
    assert_select "#school_staff_registration_school_code_error", text: /Code d'établissement invalide/
    assert_not Orm::User.exists?(contact: "0701020304")

    register_direction(Entities::School::SchoolCode.display(new_code))

    assert_redirected_to school_admin_classrooms_path
    assert_equal [ @school.id ], Orm::SchoolStaff.pluck(:school_id)
  end

  test "RM-18: after the regeneration of the links, the old link of the classroom is dead and the new one is read" do
    old_token = @classroom.link_token
    sign_in_as @admin
    perform_enqueued_jobs { launch("classroom_links") }
    sign_out

    get join_classroom_path(old_token)
    follow_redirect! if response.redirect?

    assert_response :success
    assert_select "#classroom-link-invalid[role=alert]"

    get join_classroom_path(@classroom.reload.link_token)
    follow_redirect! if response.redirect?

    assert_response :success
    assert_select "#classroom-link-invalid", 0
  end
end

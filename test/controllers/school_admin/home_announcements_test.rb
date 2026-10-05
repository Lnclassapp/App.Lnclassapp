require "test_helper"

# AD-14 to AD-16 (UDR-0074 §3.10, owner's decision of 2026-10-04): the direction's home shows the student carousel of
# the announcements it reads, between « Niveaux » and « Activité récente », in reading only: no card carries a cross,
# and a forged dismissal is refused by the announcements' own rule (ADR-0078 §4.2, unchanged).
class SchoolAdmin::HomeAnnouncementsTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Cocody")
    @admin = create_school_admin(school: @school)
    @team = create_team_member(second_factor: false)
    create_classroom(school: @school, level: create_level(name: "3ème", position: 4), name: "3ème 1")
  end

  def sections = css_select("main [id]").map { it["id"] } & %w[direction_home_school direction_home_levels student_home_announcements direction_home_activity]

  test "AD-14: the national and the school's announcements show, another school's never, between the levels and the activity" do
    national = create_message(author: @team, title: "Rentrée numérique", audience: "all")
    own = create_message(author: @team, title: "Réunion des directions", audience: "school_admins", school: @school)
    create_message(author: @team, title: "Ailleurs", audience: "school_admins", school: create_school(name: "Lycée de Yopougon"))
    create_message(author: @team, title: "Pour les élèves", audience: "students")
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_response :success
    assert_equal %w[direction_home_school direction_home_levels student_home_announcements direction_home_activity], sections
    assert_select "#student_home_announcements" do
      assert_select "li", text: /Rentrée numérique/
      assert_select "li", text: /Réunion des directions/
      assert_select "a[href=?]", announcements_path
    end
    assert_no_match(/Ailleurs|Pour les élèves/, css_select("#student_home_announcements").text)
    [ national, own ].each { assert_select "form[action=?]", announcement_dismissal_path(it.public_id), count: 0 }
  end

  test "AD-15: no card of the direction's carousel carries a cross, and a forged dismissal is refused, nothing stored" do
    message = create_message(author: @team, title: "Rentrée numérique", audience: "all")
    sign_in_as @admin

    get school_admin_classrooms_path
    assert_select "#student_home_announcements button[aria-label]", count: 0

    post announcement_dismissal_path(message.public_id), as: :turbo_stream

    assert_response :forbidden
    assert_equal 0, Orm::MessageDismissal.count
  end

  test "AD-16: without any readable announcement, the home has no « Annonces » section" do
    create_message(author: @team, title: "Pour les élèves", audience: "students")
    create_message(author: @team, title: "Brouillon", audience: "all", status: "draft", published_at: nil)
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_response :success
    assert_select "#student_home_announcements", count: 0
    assert_equal %w[direction_home_school direction_home_levels direction_home_activity], sections
  end
end

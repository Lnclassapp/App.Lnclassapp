require "test_helper"

# CA-E10 (mvp-teacher-student, lot O2) — UDR « écrans élève sans répétition » §3.6 bis. « Mon établissement » : Nom, Sigle, DRENA, Type
# de l'établissement de la classe de l'élève connecté, en lecture seule. L'établissement vient du compte de la session, jamais
# d'un paramètre ; un enseignant, la direction, l'équipe et un visiteur n'y entrent pas.
class School::StudentSchoolsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Collège Moderne 1 de Tiassalé", sigle: "CM1T", school_type: "public",
                            drena: create_drena(name: "Agboville"))
    @student = create_student(classroom: create_classroom(name: "3e B", school: @school), first_name: "Aya", last_name: "Kouassi")
  end

  def tl(key, **) = I18n.t("school.student_schools.#{key}", **)

  test "the route is GET /students/school" do
    assert_equal "/students/school", student_school_path
  end

  test "CA-E10: the student reads Nom, Sigle, DRENA and Type of their school, read only" do
    sign_in_as @student

    get student_school_path

    assert_response :success
    assert_select "title", text: /\A#{Regexp.escape(tl('show.page_title'))}/
    assert_select "#main h1", tl("show.title")
    assert_select "#main a[href='#{student_home_path}']", text: /#{Regexp.escape(tl('show.back'))}/
    assert_select "#student_school[aria-labelledby=student_school_title]" do
      assert_select "#student_school_title", tl("show.information")
      assert_equal [ "Nom Collège Moderne 1 de Tiassalé", "Sigle CM1T", "DRENA Agboville", "Type Public" ],
                   css_select("#student_school li").map { it.text.squish }
      assert_select "a, button, form, input", 0
    end
  end

  test "CA-E10: without an acronym, the Sigle row is absent" do
    @school.update!(sigle: nil)
    sign_in_as @student

    get student_school_path

    assert_response :success
    assert_equal [ "Nom Collège Moderne 1 de Tiassalé", "DRENA Agboville", "Type Public" ],
                 css_select("#student_school li").map { it.text.squish }
  end

  test "CA-E10: a private school is told « Privé »" do
    @school.update!(school_type: "private")
    sign_in_as @student

    get student_school_path

    assert_select "#student_school li", text: "Type Privé"
  end

  test "CA-E10: the student sees the school of their own classroom only, whatever the parameters" do
    other = create_school(name: "Lycée Classique d'Abidjan", sigle: "LCA")
    sign_in_as @student

    get student_school_path(school_id: other.id, id: other.public_id, school_public_id: other.public_id, student_id: 0)

    assert_response :success
    assert_select "#student_school li", text: /Collège Moderne 1 de Tiassalé/
    assert_no_match "Lycée Classique d'Abidjan", response.body
    assert_no_match other.public_id, response.body
  end

  test "a student without an active classroom is sent to the home that offers to choose one" do
    sign_in_as create_student

    get student_school_path

    assert_redirected_to student_home_path
  end

  test "a student who left their classroom is sent to the home too" do
    Orm::ClassroomStudent.where(student_id: @student.id).update_all(left_at: 1.day.ago)
    sign_in_as @student

    get student_school_path

    assert_redirected_to student_home_path
  end

  test "a student whose classroom is archived is sent to the home too" do
    Orm::Classroom.where(id: Orm::ClassroomStudent.where(student_id: @student.id).select(:classroom_id))
                  .update_all(status: "archived", archived_at: Time.current)
    sign_in_as @student

    get student_school_path

    assert_redirected_to student_home_path
  end

  test "a teacher, the direction and the team are refused, and see nothing of the school" do
    [ create_teacher(school: @school, classrooms: [ create_classroom(school: @school) ]), create_school_admin(school: @school),
      create_team_member ].each do |user|
      sign_in_as user

      get student_school_path

      assert_response :forbidden
      assert_no_match "CM1T", response.body
      sign_out
    end
  end

  test "without a session, the page sends to the sign-in" do
    get student_school_path

    assert_redirected_to new_session_path
  end
end

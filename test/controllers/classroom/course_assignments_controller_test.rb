require "test_helper"

# CA-27, UDR-0030: from a published course, the teacher opens « Assigner à mes classes » and sees each of their active
# classrooms with « Assigné » or « Assigner ». The old footer was never rendered: nothing set @teacher_classrooms.
class Classroom::CourseAssignmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tle = create_classroom(name: "Tle D 1", level: create_level(name: "Tle"), series: create_series(name: "D"),
                            school: create_school(name: "Lycée Classique"))
    @premiere = create_classroom(name: "1ère D 2")
    @teacher = create_teacher(classrooms: [ @tle, @premiere ])
    @course = create_course(name: "Génétique et évolution", material: create_material(name: "SVT", category: "science"),
                            subtitle: "Du gène à l'espèce")
  end

  def tl(key, **) = I18n.t("classroom.course_assignments.index.#{key}", **)
  def toggle(key) = I18n.t("classroom.assignments.toggle.#{key}")
  def including(text) = /#{Regexp.escape(text)}/
  def toggle_id(classroom) = "#assignment_#{classroom.public_id}_Course_#{@course.slug}"

  test "the teacher sees the course and each active classroom with the state of its toggle" do
    assignment = create_assignment(classroom: @tle, assignable: @course, by: @teacher)
    create_assignment(classroom: @premiere, assignable: @course, by: @teacher, status: "archived")
    sign_in_as @teacher

    get course_assignments_path(@course.slug)

    assert_response :success
    assert_select "title", text: including(tl("page_title", course: "Génétique et évolution"))
    assert_select "h1", text: "Génétique et évolution"
    assert_select "a[href='#{course_path(@course.slug)}']", text: including(tl("back"))
    assert_select "#course_assignment_classrooms li", 2
    assert_select "#course_assignment_classrooms", text: including("Tle D · Lycée Classique")
    assert_select "a[href='#{classroom_path(@tle.public_id)}']", text: "Tle D 1"
    assert_select "[role=group][aria-label='#{tl('classroom_assignment', classroom: 'Tle D 1')}']"
    assert_select toggle_id(@tle) do
      assert_select "*", text: including(toggle(:assigned))
      assert_select "form[action='#{archive_assignment_path(assignment.public_id)}']"
    end
    assert_select toggle_id(@premiere) do
      assert_select "form[action='#{classroom_assignments_path(@premiere.public_id)}']"
      assert_select "input[name='assignment[assignable_type]'][value='Course']"
      assert_select "input[name='assignment[assignable_key]'][value='#{@course.slug}']"
    end
  end

  test "an archived classroom or another teacher's classroom is not offered" do
    archived = create_classroom(name: "Archivée", status: "archived")
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom: archived)
    create_teacher(classrooms: [ create_classroom(name: "Autre") ])
    sign_in_as @teacher

    get course_assignments_path(@course.slug)

    assert_select "#course_assignment_classrooms li", 2
    assert_select "#course_assignment_classrooms", text: /Archivée|Autre/, count: 0
  end

  test "a teacher without an active classroom is invited to declare their classrooms" do
    sign_in_as create_teacher

    get course_assignments_path(@course.slug)

    assert_response :success
    assert_select "#course_assignment_classrooms", text: including(tl("empty"))
    assert_select "#course_assignment_classrooms a[href='#{teacher_classrooms_path}']", text: including(tl("declare"))
    assert_select "#course_assignment_classrooms", text: including(tl("classrooms_hint")), count: 0
  end

  test "an unknown, draft or archived course: 404" do
    sign_in_as @teacher

    [ "inconnu", create_course(status: "draft").slug, create_course(status: "archived").slug ].each do |slug|
      get course_assignments_path(slug)
      assert_response :not_found
    end
  end

  test "the team and a student receive 403, without the course" do
    [ create_team_member, create_student(classroom: @tle) ].each do |user|
      sign_in_as user

      get course_assignments_path(@course.slug)

      assert_response :forbidden
      assert_no_match "Génétique et évolution", response.body
      sign_out
    end
  end

  test "an anonymous visitor is sent to sign in" do
    get course_assignments_path(@course.slug)

    assert_redirected_to new_session_path
  end
end

require "test_helper"

# CL-11, UDR-0028: the teacher opens a course from their classroom and sees its published essential sheets, each one
# « Assigné » or « Assigner ». The old screen raised NameError as soon as the course had a sheet.
class Classroom::ClassroomCoursesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée Classique"))
    @teacher = create_teacher(classrooms: [ @classroom ])
    @course = create_course(name: "Génétique et évolution", material: create_material(name: "SVT", category: "science"),
                            subtitle: "Du gène à l'espèce")
    @meiose = create_essential(course: @course, name: "La méiose")
    @mitose = create_essential(course: @course, name: "La mitose")
  end

  def tl(key, **) = I18n.t("classroom.classroom_courses.show.#{key}", **)
  def toggle(key) = I18n.t("classroom.assignments.toggle.#{key}")
  def including(text) = /#{Regexp.escape(text)}/
  def toggle_id(type, key) = "#assignment_#{@classroom.public_id}_#{type}_#{key}"

  test "the teacher sees the course, its published sheets, and the assignment state of each" do
    create_essential(course: @course, name: "Brouillon", status: "draft")
    assignment = create_assignment(classroom: @classroom, assignable: @meiose, by: @teacher)
    create_exercise(essential: @meiose)
    sign_in_as @teacher

    get classroom_course_path(@classroom.public_id, @course.slug)

    assert_response :success
    assert_select "h1", text: "Génétique et évolution"
    assert_select "a[href='#{classroom_path(@classroom.public_id)}']", text: including("Tle D 1")
    assert_select toggle_id("Course", @course.slug), text: including(toggle(:assign))
    assert_select "#classroom_course_essentials li", 2
    assert_select "#classroom_course_essentials li", text: /Brouillon/, count: 0
    assert_select toggle_id("Essential", @meiose.slug) do
      assert_select "*", text: including(toggle(:assigned))
      assert_select "form[action='#{archive_assignment_path(assignment.public_id)}']"
    end
    assert_select toggle_id("Essential", @mitose.slug), text: including(toggle(:assign))
    assert_select "a[href='#{classroom_essential_path(@classroom.public_id, @course.slug, @meiose.slug)}']", text: "La méiose"
    assert_select "#classroom_course_essentials", text: including(tl("exercises", count: 1))
  end

  test "an assigned course shows « Assigné »" do
    create_assignment(classroom: @classroom, assignable: @course, by: @teacher)
    sign_in_as @teacher

    get classroom_course_path(@classroom.public_id, @course.slug)

    assert_select toggle_id("Course", @course.slug), text: including(toggle(:assigned))
  end

  test "a course without published sheet shows the empty state" do
    course = create_course
    sign_in_as @teacher

    get classroom_course_path(@classroom.public_id, course.slug)

    assert_response :success
    assert_select "#classroom_course_essentials", text: including(tl("empty"))
  end

  test "an archived classroom shows the assignment states without any toggle" do
    archived = create_classroom(status: "archived")
    teacher = create_teacher(classrooms: [ archived ])
    create_assignment(classroom: archived, assignable: @meiose, by: teacher, status: "active")
    sign_in_as teacher

    get classroom_course_path(archived.public_id, @course.slug)

    assert_response :success
    assert_select "p", text: including(tl("archived_notice"))
    assert_select "form[action*=assignments]", 0
    assert_select "#classroom_course_essentials", text: including(toggle(:assigned))
  end

  test "the team reads the page with its toggles" do
    sign_in_as create_team_member

    get classroom_course_path(@classroom.public_id, @course.slug)

    assert_response :success
    assert_select toggle_id("Course", @course.slug)
  end

  test "another teacher or a student of the classroom receives 403, without the course" do
    [ create_teacher, create_student(classroom: @classroom) ].each do |user|
      sign_in_as user

      get classroom_course_path(@classroom.public_id, @course.slug)

      assert_response :forbidden
      assert_no_match "Génétique et évolution", response.body
      sign_out
    end
  end

  test "an unknown classroom, an unknown or unpublished course: 404" do
    draft = create_course(status: "draft")
    sign_in_as @teacher

    get classroom_course_path("inconnue", @course.slug)
    assert_response :not_found
    [ "inconnu", draft.slug ].each do |slug|
      get classroom_course_path(@classroom.public_id, slug)
      assert_response :not_found
    end
  end
end

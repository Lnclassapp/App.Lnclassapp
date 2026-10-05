require "test_helper"

# CL-11, UDR-0028 (amended 2026-10-02): the teacher opens a course from their classroom and sees its published essential
# sheets, each one a link to the sheet in the classroom. Since ADR-0072 neither the course nor a sheet is assigned: the
# page has no toggle at all. The old screen raised NameError as soon as the course had a sheet.
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
  def no_toggle = assert_select("[id^=assignment_], form[action*=assignments], [role=group]", 0)

  test "the teacher sees the course and its published sheets, each a link, without any toggle" do
    create_essential(course: @course, name: "Brouillon", status: "draft")
    create_assignment(classroom: @classroom, assignable: create_exercise(essential: @meiose), by: @teacher)
    sign_in_as @teacher

    get classroom_course_path(@classroom.public_id, @course.slug)

    assert_response :success
    assert_select "h1", text: "Génétique et évolution"
    assert_select "a[href='#{classroom_path(@classroom.public_id)}']", text: including("Tle D 1")
    assert_select "#classroom_course_essentials li", 2
    assert_select "#classroom_course_essentials li", text: /Brouillon/, count: 0
    assert_select "a[href='#{classroom_essential_path(@classroom.public_id, @course.slug, @meiose.slug)}']", text: "La méiose"
    assert_select "a[href='#{classroom_essential_path(@classroom.public_id, @course.slug, @mitose.slug)}']", text: "La mitose"
    assert_select "#classroom_course_essentials_title", text: "Essentielles de la leçon"
    assert_select "#classroom_course_essentials", text: /exercice/, count: 0
    no_toggle
  end

  # ADR-0072, UDR-0028 (amendée le 2026-10-02) : la bascule du cours, celle de chaque fiche et l'aide disparaissent.
  test "neither the course nor a sheet offers « Assigner », and the hint about assigning a sheet is gone" do
    sign_in_as @teacher

    get classroom_course_path(@classroom.public_id, @course.slug)

    assert_response :success
    assert_no_match including(toggle(:assign)), response.body
    assert_no_match(/Assignez une fiche essentielle/, response.body)
    no_toggle
  end

  test "a course without published sheet shows the empty state" do
    course = create_course
    sign_in_as @teacher

    get classroom_course_path(@classroom.public_id, course.slug)

    assert_response :success
    assert_select "#classroom_course_essentials", text: including(tl("empty"))
  end

  test "an archived classroom shows its notice, without any toggle nor « Assigné » badge" do
    archived = create_classroom(status: "archived")
    teacher = create_teacher(classrooms: [ archived ])
    create_assignment(classroom: archived, assignable: create_exercise(essential: @meiose), by: teacher, status: "active")
    sign_in_as teacher

    get classroom_course_path(archived.public_id, @course.slug)

    assert_response :success
    assert_select "p", text: including(tl("archived_notice"))
    assert_select "#classroom_course_essentials", text: including(toggle(:assigned)), count: 0
    no_toggle
  end

  test "the team reads the page, without any toggle either" do
    sign_in_as create_team_member

    get classroom_course_path(@classroom.public_id, @course.slug)

    assert_response :success
    assert_select "#classroom_course_essentials li", 2
    no_toggle
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

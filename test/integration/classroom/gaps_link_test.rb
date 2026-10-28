require "test_helper"

# CA-25, ADR-0113 §4, UDR-0138 §3.7, UDR-0139: every « Notion à revoir » leads to the lesson page, on the anchor of the
# notion in « Prépare interros », where its exercise is. Nothing leads to a notion page any more.
class Classroom::GapsLinkTest < ActionDispatch::IntegrationTest
  setup do
    @maths = create_material(name: "Mathématiques")
    @level = create_level(name: "3ème")
    @classroom = create_classroom(level: @level, name: "3ème 1")
    @teacher = create_teacher(school: @classroom.school, classrooms: [ @classroom ], material: @maths)
    @course = create_course(name: "Géométrie", level: @level, material: @maths)
    @notion = create_essential(course: @course, name: "Théorème de Thalès")
    create_exercise(essential: @notion, questions: 1)
    @student = create_student(classroom: @classroom)
    create_gap(student: @student, essential: @notion)
  end

  def anchor = "notion-#{@notion.slug}"

  test "the student home sends « Revoir la notion » to the lesson, on the notion" do
    sign_in_as @student

    get student_home_path

    assert_select "section#student_next_step[data-state=review] a.ui-button-primary[href=?]", course_path(@course.slug, anchor:)
  end

  test "the « Notions à revoir » of the student classroom lead to the lesson, on the notion" do
    sign_in_as @student

    get student_classroom_path

    assert_select "#student_classroom_gaps a[href=?]", course_path(@course.slug, anchor:), text: /Théorème de Thalès/
    assert_select "#student_classroom_gaps a[href*='/essentials/']", 0
  end

  test "CA-25: the teacher's class names the notion, and its link leads to the lesson in the classroom, on the notion" do
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_select "#classroom_gaps li a[href=?]", classroom_course_path(@classroom.public_id, @course.slug, anchor:),
                  text: "Théorème de Thalès"
    assert_select "#classroom_gaps a[href*='/essentials/']", 0
  end

  test "the anchor exists on the lesson page, with the exercise of the notion under it" do
    sign_in_as @student

    get course_path(@course.slug)

    assert_select "div##{anchor}"
  end
end

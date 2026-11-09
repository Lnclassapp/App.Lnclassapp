require "test_helper"

# suivi-classe-lecon Lot A (CA-1, CA-4, CA-12, côté encadré) : sous chaque notion de la leçon vue depuis la classe, l'encadré
# « Dans votre classe » nomme les élèves à revoir et ceux qui ont levé leur lacune ; sans lacune, pas d'encadré.
class Classroom::NotionGapsInLessonTest < ActionDispatch::IntegrationTest
  setup do
    @level = create_level(name: "3ème")
    @course = create_course(name: "Géométrie", level: @level)
    @thales = create_essential(course: @course, name: "Théorème de Thalès", position: 1, sheet: sheet_of("Théorème de Thalès"))
    @pythagore = create_essential(course: @course, name: "Pythagore", position: 2, sheet: sheet_of("Pythagore"))
    @classroom = create_classroom(level: @level, school_year: "2026-2027")
    @teacher = create_teacher(school: @classroom.school, classrooms: [ @classroom ])
    @awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
    @koffi = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")
    source = create_exercise(essential: @thales, questions: 1)
    [ [ @awa, "pending", {} ], [ @koffi, "remediated", { resolved_at: Time.zone.local(2026, 10, 15, 9) } ] ].each do |student, status, attrs|
      session = create_exercise_session(student:, exercise: source, status: "completed", score_percent: 30)
      create_gap(student:, essential: @thales, status:, source_session: session, **attrs)
    end
  end

  def sheet_of(name)
    notion = revision_notion(name)
    { "remember" => notion["remember"], "method" => notion["method"], "example" => notion["example"], "pitfall" => notion["pitfall"] }
  end

  def open_lesson = get classroom_course_path(@classroom.public_id, @course.slug)

  test "CA-1: the teacher reads who is to review and who lifted the gap, under the notion" do
    sign_in_as @teacher
    travel_to Time.zone.local(2026, 11, 5, 10) do
      open_lesson
    end

    assert_response :success
    assert_select "section#notion-#{@thales.slug} aside#notion-gaps-#{@thales.slug}" do
      assert_select "h3", text: "Dans votre classe"
      assert_select "h4", text: "À revoir (1)"
      assert_select "h4", text: "Lacune levée (1)"
      assert_select "li", text: /Awa Bamba/
      assert_select "li", text: /Koffi Yao.*levée le/m
    end
  end

  test "CA-4: a notion without gap has no box" do
    sign_in_as @teacher
    open_lesson

    assert_select "aside#notion-gaps-#{@thales.slug}", 1
    assert_select "aside#notion-gaps-#{@pythagore.slug}", 0
  end

  test "CA-12: the principal of the same school sees the box" do
    director = create_school_admin(school: @classroom.school)
    sign_in_as director
    open_lesson

    assert_response :success
    assert_select "aside#notion-gaps-#{@thales.slug} li", text: /Awa Bamba/
  end

  test "the student lesson page has no box" do
    sign_in_as @awa
    get course_path(@course.slug)

    assert_select "aside[id^=notion-gaps]", 0
  end
end

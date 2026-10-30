require "test_helper"

# UDR-0139 §3.4, refonte-page-lecon (CA-06, CA-10, CA-11): « Prépare interros » on the lesson page.
class Catalog::PrepareInterrosTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Thalès")
    @notions = Array.new(4) { |index| create_essential(course: @course, name: "Notion #{index + 1}", position: index + 1) }
    @by_notion = @notions.map { |essential| create_exercise(essential:, title: "Exercice #{essential.name}", exercise_type: "fixation") }
    @wide = Array.new(4) { |index| create_lesson_wide_exercise(course: @course, title: "Toute la leçon #{index + 1}", exercise_type: "evaluation") }
    @classroom = create_classroom(level: @course.level, series: @course.series)
    @student = create_student(classroom: @classroom)
    @teacher = create_teacher(classrooms: [ @classroom ])
  end

  def tl(key, **) = I18n.t("catalog.courses.show.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def row(exercise) = "#prepare-interros li#exercise-#{exercise.public_id}"

  # CA-06
  test "a student reads the 4 fixations in « Prépare interros » and the 4 evaluations in « Prépare devoirs », each with type and question count" do
    sign_in_as @student

    get course_path(@course.slug)

    assert_response :success
    assert_select "#prepare-interros li[id^=exercise-]", 4
    assert_equal @by_notion.map(&:title), css_select("#prepare-interros li[id^=exercise-] h3 a").map { it.text.squish }
    assert_equal @wide.map(&:title), css_select("#prepare-devoirs li[id^=exercise-] h3 a").map { it.text.squish }
    assert_select "ul#prepare-interros-grid.grid[class~='sm:grid-cols-2'][class~='xl:grid-cols-3'][class~='2xl:grid-cols-4']", 1
    assert_select "ul#prepare-devoirs-grid.grid[class~='sm:grid-cols-2'][class~='xl:grid-cols-3'][class~='2xl:grid-cols-4']", 1
    assert_select "#prepare-interros-grid > li[id^=exercise-]", 4
    assert_select "#prepare-devoirs-grid > li[id^=exercise-]", 4
    assert_select "#prepare-interros-grid > li:first-child > span#notion-#{@notions.first.slug}[aria-label='Notion 1']", 1
    assert_select "#prepare-devoirs-grid > li > span#toute-la-lecon[aria-label=?]", tl("lesson_wide_title")
    assert_select "#toute-la-lecon", 1
    assert_select "#prepare-interros h3", text: "Notion 1", count: 0
    assert_select "#prepare-devoirs h3", text: tl("lesson_wide_title"), count: 0
    assert_select row(@by_notion.first), text: including("Fixation")
    assert_select row(@by_notion.first), text: including(tl("question_count", count: 2))
    assert_select "#prepare-devoirs li#exercise-#{@wide.first.public_id}", text: including("Évaluation")
    assert_select "#prepare-interros li#exercise-#{@wide.first.public_id}", 0
    assert_select "#{row(@by_notion.first)} a[href='#{exercise_path(@by_notion.first.public_id)}']"
    assert_select "#prepare-interros form[action*=assignments], #prepare-devoirs form[action*=assignments]", 0
  end

  # CA-10
  test "a lesson without exercise says so, for a teacher too, and offers no « Assigner »" do
    course = create_course
    sign_in_as @teacher

    get course_path(course.slug)

    assert_response :success
    assert_select "#prepare-interros", text: including(tl("exercises_empty"))
    assert_select "#prepare-interros [id^=assignment_]", 0
  end

  # CA-11
  test "the student's state on each row: due day, then best grade, then « À revoir »" do
    teacher = @teacher
    assignment = travel_to(Time.zone.local(2026, 10, 26, 9)) do
      create_assignment(classroom: @classroom, assignable: @by_notion[0], by: teacher, due_on: Date.new(2026, 10, 29))
    end
    create_exercise_session(student: @student, exercise: @by_notion[1], status: "completed", score_percent: 70)
    create_gap(student: @student, essential: @notions[2])
    sign_in_as @student

    travel_to(Time.zone.local(2026, 10, 27, 9)) { get course_path(@course.slug) }

    assert_select row(@by_notion[0]), text: including(tl("due", day: "jeudi"))
    assert_select row(@by_notion[1]), text: including("14/20")
    assert_select row(@by_notion[2]), text: including(tl("to_review"))
    assert_select row(@by_notion[3]), text: /\A\s*Fixation\s+#{Regexp.escape(@by_notion[3].title)}\s+2 questions\s+Commencer\s*\z/
    assert_equal "jeudi", I18n.l(assignment.due_on, format: "%A")
  end

  test "the due day reads « aujourd'hui » the day itself, and a handed-in copy gives way to its grade" do
    assignment = travel_to(Time.zone.local(2026, 10, 26, 9)) do
      create_assignment(classroom: @classroom, assignable: @by_notion[0], by: @teacher, due_on: Date.new(2026, 10, 27))
    end
    create_exercise_session(student: @student, exercise: @by_notion[1], status: "completed", score_percent: 60)
    travel_to(Time.zone.local(2026, 10, 26, 9)) do
      create_assignment(classroom: @classroom, assignable: @by_notion[1], by: @teacher, due_on: Date.new(2026, 10, 27))
    end
    create_exercise_session(student: @student, exercise: @by_notion[0], status: "completed", score_percent: 90, classroom_assignment: assignment)
    sign_in_as @student

    travel_to(Time.zone.local(2026, 10, 27, 9)) { get course_path(@course.slug) }

    assert_select row(@by_notion[0]), text: including("18/20")
    assert_select row(@by_notion[1]), text: including(tl("due_today"))
  end

  # CA-5
  test "a teacher reads « Voir l'exercice » on each card, never « Commencer »" do
    sign_in_as @teacher

    get course_path(@course.slug)

    assert_select row(@by_notion.first), text: including("Voir l'exercice")
    assert_select row(@by_notion.first), text: including("Commencer"), count: 0
  end

  test "the team reads the status of each exercise, draft included, and has no toggle" do
    create_exercise(essential: @notions[0], title: "Brouillon", status: "draft", position: 90)
    sign_in_as create_team_member

    get course_path(@course.slug)

    assert_select "#prepare-interros li[id^=exercise-]", 5
    assert_select "#prepare-devoirs li[id^=exercise-]", 4
    assert_select "#prepare-interros li", text: including("Brouillon")
    assert_select "#prepare-interros [id^=assignment_], #prepare-devoirs [id^=assignment_]", 0
  end
end

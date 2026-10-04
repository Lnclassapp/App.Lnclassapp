require "test_helper"

# CL-12, AS-20, UDR-0029: the teacher opens an essential sheet from their classroom and sees its published exercises,
# each one « Assigné » or « Assigner », with the classroom's success rate. Since ADR-0072 the sheet itself is no longer
# assigned (UDR-0029, amended 2026-10-02): its header has no toggle. The old screen raised PG::UndefinedColumn as soon as
# the sheet had an exercise.
class Classroom::ClassroomEssentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée Classique"))
    @teacher = create_teacher(classrooms: [ @classroom ])
    @course = create_course(name: "Génétique et évolution")
    @essential = create_essential(course: @course, name: "La méiose", subtitle: "Deux divisions")
    @phases = create_exercise(essential: @essential, title: "Les phases", questions: 3)
    @brassage = create_exercise(essential: @essential, title: "Le brassage", questions: 1)
  end

  def tl(key, **) = I18n.t("classroom.classroom_essentials.show.#{key}", **)
  def toggle(key) = I18n.t("classroom.assignments.toggle.#{key}")
  def including(text) = /#{Regexp.escape(text)}/
  def toggle_id(type, key) = "#assignment_#{@classroom.public_id}_#{type}_#{key}"
  def page_path(classroom = @classroom, essential = @essential) = classroom_essential_path(classroom.public_id, @course.slug, essential.slug)

  test "the teacher sees the sheet, its published exercises, their assignment state and the classroom success rate" do
    create_exercise(essential: @essential, title: "Brouillon", status: "draft")
    assignment = create_assignment(classroom: @classroom, assignable: @phases, by: @teacher)
    student = create_student(classroom: @classroom)
    create_exercise_session(student:, exercise: @phases, status: "completed", score_percent: 72)
    sign_in_as @teacher

    get page_path

    assert_response :success
    assert_select "h1", text: "La méiose"
    assert_select "a[href='#{classroom_course_path(@classroom.public_id, @course.slug)}']", text: including("Génétique et évolution")
    assert_select "*", text: including(tl("context", classroom: "Tle D 1", school: "Lycée Classique"))
    assert_select "[id^='assignment_#{@classroom.public_id}_Essential']", 0
    assert_select "#classroom_essential_exercises li", 2
    assert_select "#classroom_essential_exercises li", text: /Brouillon/, count: 0
    assert_select toggle_id("Exercise", @phases.public_id) do
      assert_select "*", text: including(toggle(:assigned))
      assert_select "form[action='#{archive_assignment_path(assignment.public_id)}']"
    end
    assert_select toggle_id("Exercise", @brassage.public_id), text: including(toggle(:assign))
    assert_select "#classroom_essential_exercises", text: including(tl("questions", count: 3))
    assert_select "#classroom_essential_exercises", text: including(tl("success_rate", percent: 100, passed: 1, count: 1))
    assert_select "#classroom_essential_exercises", text: including(tl("no_result"))
  end

  # ADR-0072, UDR-0029 (amendée le 2026-10-02) : la bascule de la fiche et son role="group" disparaissent de l'en-tête.
  test "the header of the sheet has no toggle nor group, only the exercises carry one" do
    # Jours renseignés : les bascules sont des formulaires (sans eux, des liens vers la modale des jours, UDR-0062 §3.4).
    Repositories::Classroom::SessionDaysRepository.new.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 1 ],
                                                                at: Time.current)
    sign_in_as @teacher

    get page_path

    assert_response :success
    assert_select "[role=group]", 0
    assert_select "form[action='#{classroom_assignments_path(@classroom.public_id)}'] input[name='assignment[assignable_type]']" do |inputs|
      assert_equal [ "Exercise" ], inputs.map { it["value"] }.uniq
    end
  end

  test "a sheet without published exercise shows the empty state" do
    essential = create_essential(course: @course)
    sign_in_as @teacher

    get page_path(@classroom, essential)

    assert_response :success
    assert_select "#classroom_essential_exercises", text: including(tl("empty"))
  end

  test "an archived classroom shows the assignment states without any toggle" do
    archived = create_classroom(status: "archived")
    teacher = create_teacher(classrooms: [ archived ])
    create_assignment(classroom: archived, assignable: @phases, by: teacher)
    sign_in_as teacher

    get page_path(archived)

    assert_response :success
    assert_select "p", text: including(tl("archived_notice"))
    assert_select "form[action*=assignments]", 0
    assert_select "#classroom_essential_exercises", text: including(toggle(:assigned))
    assert_select "[role=group]", 0
    assert_select "#classroom_essential_exercises", text: including(tl("hint")), count: 0
  end

  test "the team reads the page with its toggles" do
    sign_in_as create_team_member

    get page_path

    assert_response :success
    assert_select toggle_id("Exercise", @phases.public_id)
  end

  test "another teacher or a student of the classroom receives 403, without the sheet" do
    [ create_teacher, create_student(classroom: @classroom) ].each do |user|
      sign_in_as user

      get page_path

      assert_response :forbidden
      assert_no_match "La méiose", response.body
      sign_out
    end
  end

  test "an unknown classroom, an unknown or unpublished sheet: 404" do
    draft = create_essential(course: @course, status: "draft")
    sign_in_as @teacher

    get classroom_essential_path("inconnue", @course.slug, @essential.slug)
    assert_response :not_found
    [ "inconnue", draft.slug ].each do |slug|
      get classroom_essential_path(@classroom.public_id, @course.slug, slug)
      assert_response :not_found
    end
  end

  # UDR-0062 §3.4 : sans jours de séance, « Assigner » est un lien vers la modale des jours, dans le frame « modal ».
  test "a teacher without session days: « Assigner » links to the days modal; with days, it posts directly" do
    sign_in_as @teacher

    get page_path

    assert_select toggle_id("Exercise", @phases.public_id) do
      assert_select "a[href='#{new_classroom_assignment_path(@classroom.public_id, assignable_key: @phases.public_id)}'][data-turbo-frame=modal]",
                    text: including(toggle(:assign))
      assert_select "form", 0
    end

    Repositories::Classroom::SessionDaysRepository.new.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 1, 4 ],
                                                                at: Time.current)
    get page_path

    assert_select toggle_id("Exercise", @phases.public_id) do
      assert_select "form[action='#{classroom_assignments_path(@classroom.public_id)}']"
      assert_select "a[data-turbo-frame=modal]", 0
    end
  end

  # UDR-0069 §3.8 : la bascule nomme la classe dès le premier rendu, comme après un stream (et comme au catalogue).
  test "the toggle's accessible name names the exercise and the classroom" do
    sign_in_as @teacher

    get page_path

    label = I18n.t("classroom.assignments.toggle.assign_to_label", name: "Les phases", classroom: "Tle D 1")
    assert_select "#{toggle_id("Exercise", @phases.public_id)} [aria-label='#{label}']"
  end

  test "the team never gets the days modal" do
    sign_in_as create_team_member

    get page_path

    assert_select "a[href^='#{new_classroom_assignment_path(@classroom.public_id)}']", 0
    assert_select "#{toggle_id('Exercise', @phases.public_id)} form[action='#{classroom_assignments_path(@classroom.public_id)}']"
  end

  test "an assigned exercise shows its due date for the teacher, only when it has one" do
    create_assignment(classroom: @classroom, assignable: @phases, by: @teacher, due_on: Date.new(2026, 10, 8),
                      assigned_at: Time.zone.local(2026, 10, 5, 10))
    create_assignment(classroom: @classroom, assignable: @brassage, by: @teacher)
    sign_in_as @teacher

    get page_path

    assert_select toggle_id("Exercise", @phases.public_id), text: including("Pour jeu. 8 oct.")
    assert_select toggle_id("Exercise", @brassage.public_id), text: including("Sans date limite"), count: 0
  end
end

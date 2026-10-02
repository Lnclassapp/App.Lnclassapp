require "test_helper"

# Lot E of fonctions-espace-eleve (UDR-0062 §3.5, ADR-0072 §4.4, §4.5): the follow-up of an assigned exercise. Its
# teacher and the team read the three counts and the names of the students who handed it in late; a student, another
# teacher and the school's direction get 403, a visitor goes to the sign-in page. The policy runs before any reading.
class Classroom::AssignmentFollowUpsControllerTest < ActionDispatch::IntegrationTest
  DUE_ON = Date.new(2026, 10, 8)

  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school: @school, name: "3ème B")
    @teacher = create_teacher(school: @school, classrooms: [ @classroom ])
    svt = create_material(name: "SVT", category: "science")
    @exercise = create_exercise(essential: create_essential(course: create_course(material: svt)), title: "La méiose")
    @assignment = travel_to(Time.zone.local(2026, 10, 2, 9)) do
      create_assignment(classroom: @classroom, assignable: @exercise, by: @teacher, due_on: DUE_ON)
    end
    @late = [ %w[Koffi Yao], %w[Awa Bamba] ].map do |first_name, last_name|
      create_student(classroom: @classroom, first_name:, last_name:).tap { hand_in(it, Time.zone.local(2026, 10, 9, 10)) }
    end
    @on_time = create_student(classroom: @classroom, first_name: "Jean", last_name: "Kouassi")
    hand_in(@on_time, Time.zone.local(2026, 10, 8, 18))
    @pending = create_student(classroom: @classroom, first_name: "Zoé", last_name: "Pas-Encore")
  end

  def scope = "classroom.assignment_follow_ups.show"
  def follow_up_path(assignment = @assignment) = classroom_assignment_path(@classroom.public_id, assignment.public_id)

  def hand_in(student, at, assignment: @assignment)
    create_exercise_session(student:, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed",
                            classroom_assignment: assignment, completed_at: at)
  end

  test "the classroom's teacher reads the counts and the late students, by name, with the day of their first hand-in" do
    sign_in_as @teacher

    get follow_up_path

    assert_response :success
    assert_select "title", text: "La méiose · Enseignant · Lnclass"
    assert_select "nav[aria-label='Retour'] a[href='#{classroom_path(@classroom.public_id)}']", text: "3ème B"
    assert_select "p", text: I18n.t("#{scope}.context", classroom: "3ème B", school: "Lycée Classique d'Abidjan")
    assert_select "h1", text: "La méiose"
    assert_select "body", text: /SVT/
    assert_select "body", text: /Pour jeu\. 8 oct\./
    assert_select "body", text: /#{I18n.t("#{scope}.assigned_on", date: "2 oct.")}/
    assert_select "a[href='#{exercise_path(@exercise.public_id)}']", text: I18n.t("#{scope}.see_exercise")
    assert_select "dl#follow_up_counts" do
      assert_select "div", 3
      assert_select "dt", text: I18n.t("#{scope}.done")
      assert_select "dt", text: I18n.t("#{scope}.late")
      assert_select "dt", text: I18n.t("#{scope}.pending")
      assert_select "dd", text: "3"
      assert_select "dd", text: "2"
      assert_select "dd", text: "1"
    end
    assert_select "section#late_students h2", text: I18n.t("#{scope}.late_title")
    assert_select "section#late_students ul li", 2 do |items|
      assert_match(/Awa Bamba.*Fait le ven\. 9 oct\./m, items.first.text)
      assert_match(/Koffi Yao/, items.last.text)
    end
    assert_no_match(/Kouassi|Pas-Encore/, response.body)
  end

  test "no student identifier in the HTML of the follow-up" do
    sign_in_as @teacher

    get follow_up_path

    [ *@late, @on_time, @pending ].each { assert_no_match(/#{it.public_id}/, response.body) }
  end

  test "the team reads it too, and comes back to the classroom" do
    sign_in_as create_team_member

    get follow_up_path

    assert_response :success
    assert_select "section#late_students li", 2
    assert_select "nav[aria-label='Retour'] a[href='#{classroom_path(@classroom.public_id)}']"
  end

  test "without a due date: no late count, no late section, and it says so" do
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential), by: @teacher)
    hand_in(@on_time, 1.hour.ago, assignment:)
    sign_in_as @teacher

    get follow_up_path(assignment)

    assert_response :success
    assert_select "body", text: /#{I18n.t("due_dates.teacher.none")}/
    assert_select "dl#follow_up_counts div", 2
    assert_select "dt", text: I18n.t("#{scope}.late"), count: 0
    assert_select "#late_students", 0
    assert_select "p", text: I18n.t("#{scope}.no_due_date")
  end

  test "a due date nobody missed: no late section" do
    Orm::ExerciseSession.where(student: @late).update_all(completed_at: Time.zone.local(2026, 10, 7, 10))
    sign_in_as @teacher

    get follow_up_path

    assert_response :success
    assert_select "dl#follow_up_counts dt", text: I18n.t("#{scope}.late")
    assert_select "#late_students", 0
    assert_select "p", text: I18n.t("#{scope}.no_due_date"), count: 0
  end

  test "an archived assignment, or one of another classroom, answers 404" do
    archived = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential), status: "archived")
    elsewhere = create_classroom(school: @school)
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom: elsewhere)
    sign_in_as @teacher

    get follow_up_path(archived)
    assert_response :not_found

    get classroom_assignment_path(elsewhere.public_id, @assignment.public_id)
    assert_response :not_found

    get classroom_assignment_path("inconnue", @assignment.public_id)
    assert_response :not_found
  end

  test "a student of the classroom gets 403, without any name" do
    sign_in_as @late.first

    get follow_up_path

    assert_response :forbidden
    assert_no_match(/Bamba|Kouassi|Pas-Encore/, response.body)
  end

  test "a teacher of another classroom gets 403, without any name" do
    sign_in_as create_teacher(school: @school, classrooms: [ create_classroom(school: @school) ])

    get follow_up_path

    assert_response :forbidden
    assert_no_match(/Yao|Bamba|Kouassi/, response.body)
  end

  test "the school's direction gets 403: neither the late students nor any student identifier (UDR-0052)" do
    sign_in_as create_school_admin(school: @school)

    get follow_up_path

    assert_response :forbidden
    assert_no_match(/Yao|Bamba|Kouassi/, response.body)
    [ *@late, @on_time, @pending ].each { assert_no_match(/#{it.public_id}/, response.body) }
  end

  test "a visitor is sent to the sign-in page" do
    get follow_up_path

    assert_redirected_to new_session_path
  end
end

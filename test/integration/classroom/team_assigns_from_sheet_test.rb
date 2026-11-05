require "test_helper"

# suivi-classe-lecon (CA-16, UDR §3.5) : l'équipe voit la barre d'assignation sur une feuille ouverte depuis une classe,
# pour cette classe seule ; hors classe, toujours pas de barre.
class Classroom::TeamAssignsFromSheetTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Thalès")
    @notion = create_essential(course: @course, name: "Notion 1", position: 1)
    @exercise = create_exercise(essential: @notion)
    @classroom = create_classroom(name: "3e 2", level: @course.level, series: @course.series)
    @other = create_classroom(name: "3e 3", level: @course.level, series: @course.series, school: @classroom.school)
    sign_in_as create_team_member
  end

  def sheet_in_class = "/classrooms/#{@classroom.public_id}/courses/#{@course.slug}/feuilles/notion-#{@notion.slug}"
  def toggle_id(classroom) = "assignment_#{classroom.public_id}_Exercise_#{@exercise.public_id}"

  test "CA-16 the team sees « Assigner à 3e 2 » under each exercise, for this classroom only, and assigning creates the assignment" do
    get sheet_in_class

    assert_response :success
    assert_select "##{toggle_id(@classroom)} button[aria-label=?]",
                  I18n.t("classroom.assignments.toggle.assign_to_label", name: @exercise.title, classroom: "3e 2")
    assert_select "##{toggle_id(@other)}", count: 0
    assert_select "button[role=checkbox][data-batch-choice='#{@exercise.public_id}']"

    assert_difference -> { Orm::ClassroomAssignment.where(classroom_id: @classroom.id, status: "active").count }, 1 do
      post classroom_assignments_path(@classroom.public_id),
           params: { assignment: { assignable_type: "Exercise", assignable_key: @exercise.public_id }, sheet: "1" }, as: :turbo_stream
    end
    assert_response :success
  end

  test "in a classroom the team still sees « Brouillon » and gets no toggle on a draft exercise" do
    draft = create_exercise(essential: @notion, status: "draft", position: 2)

    get sheet_in_class

    assert_response :success
    assert_select ".ps-status", text: I18n.t("catalog.content_status.draft")
    assert_select "#assignment_#{@classroom.public_id}_Exercise_#{draft.public_id}", count: 0
    assert_select "button[role=checkbox][data-batch-choice='#{draft.public_id}']", count: 0
    assert_select "##{toggle_id(@classroom)}"
  end

  test "outside a classroom the team still has no bar" do
    get course_sheet_path(@course.slug, "notion-#{@notion.slug}")

    assert_response :success
    assert_select "[role=checkbox][data-batch-choice]", count: 0
    assert_select "##{toggle_id(@classroom)}", count: 0
  end
end

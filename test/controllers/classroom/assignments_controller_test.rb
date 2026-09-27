require "test_helper"

# CL-16, CL-17, CL-20, AS-18, AS-19, ADR-0048, UDR-0028: the teacher of a classroom assigns a course, an essential sheet
# or an exercise, and withdraws it. Every answer is a Turbo Stream that replaces the toggle — the old application answered
# 204 and left the button unchanged, raised RecordNotUnique on reassignment and wrote a teacher profile id as the author.
class Classroom::AssignmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom(name: "6ème 1")
    @teacher = create_teacher(classrooms: [ @classroom ])
    @course = create_course(name: "Génétique")
    @essential = create_essential(course: @course, name: "La méiose")
    @exercise = create_exercise(essential: @essential, title: "Méiose")
  end

  def tl(key, **) = I18n.t("classroom.assignments.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def toggle_id(type, key, classroom: @classroom) = "assignment_#{classroom.public_id}_#{type}_#{key}"

  def resources
    { "Course" => [ @course, @course.slug, "Génétique" ], "Essential" => [ @essential, @essential.slug, "La méiose" ],
      "Exercise" => [ @exercise, @exercise.public_id, "Méiose" ] }
  end

  def assign(type, key, classroom: @classroom, **)
    post classroom_assignments_path(classroom.public_id), params: { assignment: { assignable_type: type, assignable_key: key } }, **
  end

  def withdraw(assignment, classroom: @classroom, **)
    patch archive_assignment_path(assignment.public_id), params: { classroom_public_id: classroom.public_id }, **
  end

  test "each of the three resource types is assigned then withdrawn, in Turbo Streams that replace the toggle" do
    sign_in_as @teacher

    resources.each do |type, (record, key, name)|
      assign(type, key, as: :turbo_stream)

      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assignment = Orm::ClassroomAssignment.find_by!(assignable_type: type, assignable_id: record.id)
      assert_equal [ @classroom.id, "active", @teacher.id ], [ assignment.classroom_id, assignment.status, assignment.assigned_by_id ]
      assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("create.done", name:, classroom: "6ème 1"))
      assert_select "turbo-stream[action=replace][target='#{toggle_id(type, key)}']" do
        assert_select "template ##{toggle_id(type, key)}", text: including(tl("toggle.assigned"))
        assert_select "form[action='#{archive_assignment_path(assignment.public_id)}'] input[name=classroom_public_id][value='#{@classroom.public_id}']"
      end

      withdraw(assignment, as: :turbo_stream)

      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_equal [ "archived", @teacher.id ], assignment.reload.values_at(:status, :archived_by_id)
      assert_not_nil assignment.archived_at
      assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("archive.done", name:, classroom: "6ème 1"))
      assert_select "turbo-stream[action=replace][target='#{toggle_id(type, key)}'] template" do
        assert_select "form[action='#{classroom_assignments_path(@classroom.public_id)}']" do
          assert_select "input[name='assignment[assignable_type]'][value=#{type}]"
          assert_select "input[name='assignment[assignable_key]'][value='#{key}']"
        end
      end
    end
  end

  test "posting the same assignment again says it is already assigned (422) and writes nothing" do
    sign_in_as @teacher
    assign("Exercise", @exercise.public_id, as: :turbo_stream)

    assert_no_difference -> { Orm::ClassroomAssignment.count } do
      assign("Exercise", @exercise.public_id, as: :turbo_stream)
    end
    assert_response :unprocessable_entity
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("refusals.already_assigned"))
    assert_select "turbo-stream[action=replace]", 0
  end

  test "reassigning after a withdrawal creates a new active row, without a uniqueness error" do
    first = create_assignment(classroom: @classroom, assignable: @exercise, by: @teacher, status: "archived")
    sign_in_as @teacher

    assign("Exercise", @exercise.public_id, as: :turbo_stream)

    assert_response :success
    assert_equal [ "archived", "active" ], Orm::ClassroomAssignment.order(:id).pluck(:status)
    assert_equal "archived", first.reload.status
  end

  test "withdrawing an assignment already withdrawn says so (422) and writes nothing" do
    archived = create_assignment(classroom: @classroom, assignable: @exercise, by: @teacher, status: "archived")
    sign_in_as @teacher

    assert_no_changes -> { archived.reload.updated_at } do
      withdraw(archived, as: :turbo_stream)
    end
    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("refusals.already_archived"))
  end

  test "an unknown resource type is refused in place (422)" do
    sign_in_as @teacher

    assign("ExamSubject", "sujet", as: :turbo_stream)

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("refusals.invalid"))
    assert_equal 0, Orm::ClassroomAssignment.count
  end

  test "an unpublished resource, or an unknown one, is not found (404, in a stream)" do
    draft = create_exercise(essential: @essential, status: "draft")
    sign_in_as @teacher

    [ [ "Exercise", draft.public_id ], [ "Course", "inconnu" ] ].each do |type, key|
      assign(type, key, as: :turbo_stream)

      assert_response :not_found
      assert_equal "text/vnd.turbo-stream.html", response.media_type
    end
    assert_equal 0, Orm::ClassroomAssignment.count
  end

  test "another teacher's classroom: 403 on both actions, and nothing is written" do
    other = create_classroom
    foreign = create_assignment(classroom: other, assignable: @course)
    sign_in_as @teacher

    assign("Course", @course.slug, classroom: other, as: :turbo_stream)
    assert_response :forbidden
    withdraw(foreign, classroom: other, as: :turbo_stream)
    assert_response :forbidden

    assert_equal [ "active" ], Orm::ClassroomAssignment.pluck(:status)
  end

  test "an assignment of another classroom cannot be withdrawn through one's own classroom (404)" do
    foreign = create_assignment(classroom: create_classroom, assignable: @course)
    sign_in_as @teacher

    withdraw(foreign, as: :turbo_stream)

    assert_response :not_found
    assert_equal "active", foreign.reload.status
  end

  test "an archived classroom accepts no assignment (403)" do
    archived = create_classroom(status: "archived")
    teacher = create_teacher(classrooms: [ archived ])
    sign_in_as teacher

    assign("Course", @course.slug, classroom: archived, as: :turbo_stream)

    assert_response :forbidden
    assert_equal 0, Orm::ClassroomAssignment.count
  end

  test "a student receives 403 and writes nothing; the team may assign" do
    sign_in_as create_student(classroom: @classroom)
    assign("Course", @course.slug, as: :turbo_stream)
    assert_response :forbidden
    assert_equal 0, Orm::ClassroomAssignment.count
    sign_out

    member = create_team_member
    sign_in_as member
    assign("Course", @course.slug, as: :turbo_stream)
    assert_response :success
    assert_equal [ member.id ], Orm::ClassroomAssignment.pluck(:assigned_by_id)
  end

  test "a visitor is sent to the sign-in page" do
    assign("Course", @course.slug)

    assert_redirected_to new_session_path
  end

  test "without Turbo, every answer leads back to where the button was, with a flash" do
    origin = classroom_course_url(@classroom.public_id, @course.slug)
    sign_in_as @teacher

    assign("Course", @course.slug, headers: { "HTTP_REFERER" => origin })
    assert_redirected_to origin
    assert_equal tl("create.done", name: "Génétique", classroom: "6ème 1"), flash[:notice]

    assign("Course", @course.slug, headers: { "HTTP_REFERER" => origin })
    assert_redirected_to origin
    assert_equal tl("refusals.already_assigned"), flash[:alert]

    withdraw(Orm::ClassroomAssignment.sole)
    assert_redirected_to classroom_path(@classroom.public_id)
    assert_equal tl("archive.done", name: "Génétique", classroom: "6ème 1"), flash[:notice]

    withdraw(Orm::ClassroomAssignment.sole)
    assert_redirected_to classroom_path(@classroom.public_id)
    assert_equal tl("refusals.already_archived"), flash[:alert]
  end
end

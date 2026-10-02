require "test_helper"

# ADR-0072 §4.2, UDR-0062 §3.4: the teacher of the classroom edits their own session days from the classroom page, in the
# « modal » frame. Unchecking every day means « not answered ». Due dates already given never move.
class Classroom::SessionDaysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom(name: "3ème B")
    @teacher = create_teacher(classrooms: [ @classroom ])
  end

  def tl(key, **) = I18n.t("classroom.session_days.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def session_days(teacher = @teacher) = Orm::ClassroomSessionDay.where(teacher_id: teacher.id).order(:weekday).pluck(:weekday)
  def set_days(weekdays) = Repositories::Classroom::SessionDaysRepository.new.replace(teacher_id: @teacher.id, classroom_id: @classroom.id,
                                                                                       weekdays:, at: Time.current)

  def update(weekdays, classroom: @classroom, **)
    patch classroom_session_days_path(classroom.public_id), params: { session_days: { weekdays: [ "", *weekdays ] } }, **
  end

  test "the modal shows the six days, the current ones checked, and says due dates already given do not change" do
    set_days([ 1, 4 ])
    sign_in_as @teacher

    get edit_classroom_session_days_path(@classroom.public_id)

    assert_response :success
    assert_select "turbo-frame#modal dialog[open]" do
      assert_select "h2", text: tl("edit.title", classroom: "3ème B")
      assert_select "form[action='#{classroom_session_days_path(@classroom.public_id)}']" do
        assert_select "input[type=hidden][name=_method][value=patch]"
        assert_select "fieldset legend", text: tl("edit.legend")
        assert_equal %w[1 4], css_select("input[type=checkbox][name='session_days[weekdays][]'][checked]").map { it["value"] }
        assert_select "input[type=checkbox]", 6
      end
      assert_select "p", text: tl("edit.unchanged")
    end
    assert_select "button[type=submit]", text: including(tl("edit.submit"))
  end

  test "saving replaces the days, keeps the due dates already given, toasts and refreshes the page" do
    set_days([ 1, 4 ])
    assignment = create_assignment(classroom: @classroom, by: @teacher, due_on: Time.zone.today + 3)
    sign_in_as @teacher

    update(%w[2 5], as: :turbo_stream)

    assert_response :success
    assert_equal [ 2, 5 ], session_days
    assert_equal Time.zone.today + 3, assignment.reload.due_on
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("update.saved"))
    assert_select "turbo-stream[action=refresh]"
  end

  test "unchecking every day means « not answered »: no day left" do
    set_days([ 1, 4 ])
    sign_in_as @teacher

    update([], as: :turbo_stream)

    assert_response :success
    assert_empty session_days
  end

  test "a day out of Monday … Saturday: 422, the modal again, nothing written" do
    set_days([ 1 ])
    sign_in_as @teacher

    update(%w[7], as: :turbo_stream)

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal dialog[open]"
    assert_equal [ 1 ], session_days
  end

  test "another teacher, the team, a student: 403 on both actions, nothing written" do
    [ create_teacher, create_team_member, create_student(classroom: @classroom) ].each do |user|
      sign_in_as user

      get edit_classroom_session_days_path(@classroom.public_id)
      assert_response :forbidden, user.role
      update(%w[1], as: :turbo_stream)
      assert_response :forbidden, user.role
      sign_out
    end
    assert_equal 0, Orm::ClassroomSessionDay.count
  end

  test "an archived classroom: 403, nothing written" do
    archived = create_classroom(status: "archived")
    teacher = create_teacher(classrooms: [ archived ])
    sign_in_as teacher

    get edit_classroom_session_days_path(archived.public_id)
    assert_response :forbidden
    update(%w[1], classroom: archived, as: :turbo_stream)
    assert_response :forbidden
    assert_equal 0, Orm::ClassroomSessionDay.count
  end

  test "an unknown classroom: 404; a visitor is sent to the sign-in page" do
    sign_in_as @teacher
    get edit_classroom_session_days_path("inconnue")
    assert_response :not_found
    sign_out

    update(%w[1])
    assert_redirected_to new_session_path
  end

  test "without Turbo, saving leads back to the classroom page with a flash" do
    sign_in_as @teacher

    update(%w[3])

    assert_redirected_to classroom_path(@classroom.public_id)
    assert_equal tl("update.saved"), flash[:notice]
    assert_equal [ 3 ], session_days
  end
end

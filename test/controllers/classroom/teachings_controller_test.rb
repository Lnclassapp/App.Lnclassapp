require "test_helper"

# CL-09 (UDR-0025): declaring or withdrawing a classroom answers with the toggle and the counter in a Turbo Stream;
# a classroom of another school or an archived one is refused with 403, and nothing changes.
class Classroom::TeachingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school
    @level = create_level(name: "6ème", position: 1, cycle: "first")
    @sixth1 = create_classroom(school: @school, level: @level, name: "6ème 1")
    @sixth2 = create_classroom(school: @school, level: @level, name: "6ème 2")
    @teacher = create_teacher(school: @school, onboarded: false)
  end

  def tl(key, **) = I18n.t("classroom.teachings.#{key}", **)
  def declared_ids = Orm::TeacherClassroom.where(teacher: @teacher).order(:classroom_id).pluck(:classroom_id)

  test "declaring replaces the toggle, pressed, and the counter" do
    sign_in_as @teacher

    post classroom_teaching_path(@sixth1.public_id), as: :turbo_stream

    assert_response :success
    assert_equal [ @sixth1.id ], declared_ids
    assert_select "turbo-stream[action=replace][target=teaching_#{@sixth1.public_id}][method=morph] template" do
      assert_select "form#teaching_#{@sixth1.public_id}[action='#{classroom_teaching_path(@sixth1.public_id)}']" do
        assert_select "input[name=_method][value=delete]", 1
        assert_select "button[aria-pressed=true]", text: /6ème 1/
      end
    end
    assert_select "turbo-stream[action=replace][target=teaching_counter] template #teaching_counter",
                  text: tl("counter.count", count: 1)
  end

  test "declaring twice keeps a single declaration" do
    sign_in_as @teacher

    post classroom_teaching_path(@sixth1.public_id), as: :turbo_stream
    post classroom_teaching_path(@sixth1.public_id), as: :turbo_stream

    assert_response :success
    assert_equal [ @sixth1.id ], declared_ids
  end

  test "withdrawing replaces the toggle, released, and keeps the assignments and the sessions" do
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom: @sixth1)
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom: @sixth2)
    assignment = create_assignment(classroom: @sixth1, by: @teacher)
    session = create_exercise_session(student: create_student(classroom: @sixth1))
    sign_in_as @teacher

    delete classroom_teaching_path(@sixth1.public_id), as: :turbo_stream

    assert_response :success
    assert_equal [ @sixth2.id ], declared_ids
    assert_select "turbo-stream[target=teaching_#{@sixth1.public_id}] template form" do
      assert_select "input[name=_method]", 0
      assert_select "button[aria-pressed=false]", text: /6ème 1/
    end
    assert_select "turbo-stream[target=teaching_counter] template", text: tl("counter.count", count: 1)
    assert Orm::ClassroomAssignment.exists?(assignment.id)
    assert Orm::ExerciseSession.exists?(session.id)
  end

  test "without Turbo, both actions come back to the list with a message" do
    sign_in_as @teacher

    post classroom_teaching_path(@sixth1.public_id)

    assert_redirected_to teacher_classrooms_path
    assert_response :see_other
    assert_equal tl("create.declared", name: "6ème 1"), flash[:notice]

    delete classroom_teaching_path(@sixth1.public_id)

    assert_redirected_to teacher_classrooms_path
    assert_equal tl("destroy.withdrawn", name: "6ème 1"), flash[:notice]
    assert_empty declared_ids
  end

  test "a classroom of another school or an archived one: 403 with a toast, nothing changes" do
    elsewhere = create_classroom(level: @level, name: "6ème 1")
    archived = create_classroom(school: @school, level: @level, name: "6ème 9", status: "archived")
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom: archived)
    sign_in_as @teacher

    post classroom_teaching_path(elsewhere.public_id), as: :turbo_stream
    assert_response :forbidden
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(I18n.t('errors.codes.forbidden'))}/
    post classroom_teaching_path(archived.public_id), as: :turbo_stream
    assert_response :forbidden
    delete classroom_teaching_path(archived.public_id), as: :turbo_stream
    assert_response :forbidden

    assert_equal [ archived.id ], declared_ids
  end

  test "an unknown classroom: 404" do
    sign_in_as @teacher

    post classroom_teaching_path("inconnue"), as: :turbo_stream

    assert_response :not_found
    assert_empty declared_ids
  end

  test "a teacher without a primary school is held on the waiting screen (ADR-0063)" do
    lost = create_teacher(school: @school, onboarded: false)
    Orm::TeacherSchool.where(teacher: lost).delete_all
    sign_in_as lost

    post classroom_teaching_path(@sixth1.public_id), as: :turbo_stream

    assert_redirected_to pending_account_path
    assert_not Orm::TeacherClassroom.exists?(teacher: lost)
  end

  test "a student or a team member receives 403" do
    sign_in_as create_student(classroom: @sixth1)
    post classroom_teaching_path(@sixth1.public_id), as: :turbo_stream
    assert_response :forbidden
    sign_out

    sign_in_as create_team_member
    delete classroom_teaching_path(@sixth1.public_id), as: :turbo_stream
    assert_response :forbidden

    assert_empty Orm::TeacherClassroom.all
  end

  test "a visitor is sent to the sign-in page" do
    post classroom_teaching_path(@sixth1.public_id)

    assert_redirected_to new_session_path
  end
end

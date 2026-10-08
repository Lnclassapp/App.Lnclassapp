require "test_helper"

# CL-09, TR-08 replaced, TR-02 (UDR-0025): « Quelles classes enseignez-vous ? », then « Terminer la configuration »,
# whose state is stored on the profile — never deduced from the declared classrooms — and never loops.
class Classroom::TeachingSelectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @sixth = create_level(name: "6ème", position: 1, cycle: "first")
    @third = create_level(name: "3ème", position: 4, cycle: "first")
    @sixth1 = create_classroom(school: @school, level: @sixth, name: "6ème 1")
    @sixth2 = create_classroom(school: @school, level: @sixth, name: "6ème 2")
    @third_b = create_classroom(school: @school, level: @third, name: "3ème B")
    @teacher = create_teacher(school: @school, onboarded: false)
  end

  def tl(key, **) = I18n.t("classroom.teaching_selections.#{key}", **)
  def onboarding(key) = I18n.t("classroom.teacher_onboardings.create.#{key}")
  def onboarded?(teacher) = Orm::TeacherProfile.find_by!(user: teacher).onboarding_completed_at.present?
  def declare(*classrooms) = classrooms.each { Orm::TeacherClassroom.create!(teacher: @teacher, classroom: it) }

  test "the page lists the classrooms of the school by level, each toggle in its state, and the counter" do
    declare(@third_b)
    sign_in_as @teacher

    get teacher_classrooms_path

    assert_response :success
    assert_select "h1", tl("index.title")
    assert_select "main", text: /#{Regexp.escape(tl('index.subtitle', school: "Lycée Classique d'Abidjan"))}/
    assert_equal [ "6ème", "3ème" ], css_select("main h2").map { it.text.strip }
    assert_select "form#teaching_#{@sixth1.public_id}[action='#{classroom_teaching_path(@sixth1.public_id)}'] button[aria-pressed=false]"
    assert_select "form#teaching_#{@third_b.public_id} input[name=_method][value=delete]", 1
    assert_select "form#teaching_#{@third_b.public_id} button[aria-pressed=true]", text: /3ème B/
    assert_select "#teaching_counter[aria-live=polite]", text: I18n.t("classroom.teachings.counter.count", count: 1)
    assert_select "form#teacher-onboarding-form[action='#{teacher_onboarding_path}'] button[type=submit]", text: tl("index.finish")
  end

  test "an onboarded teacher keeps the page to change the classrooms, without « Terminer », and signs in to /teachers" do
    onboarded = create_teacher(school: @school)
    post session_path, params: { session: { contact: onboarded.contact, pin: "2468" } }
    assert_redirected_to teacher_home_path

    get teacher_classrooms_path

    assert_response :success
    assert_select "#teacher-onboarding-form", 0
    assert_select "a[href='#{teacher_home_path}']", text: tl("index.back_home")
    assert_select "#teaching_counter", text: I18n.t("classroom.teachings.counter.count", count: 0)
  end

  test "a school without a classroom this year says so, without counter nor button" do
    empty = create_teacher(school: create_school, onboarded: false)
    sign_in_as empty

    get teacher_classrooms_path

    assert_response :success
    assert_select "main", text: /#{Regexp.escape(tl('index.empty_title'))}/
    assert_select "#teaching_counter", 0
    assert_select "#teacher-onboarding-form", 0
  end

  test "TR-02: a teacher without a primary school reaches the exit screen in one redirection, which stays put" do
    Orm::TeacherSchool.where(teacher: @teacher).delete_all
    sign_in_as @teacher

    get teacher_classrooms_path

    assert_redirected_to pending_account_path
    follow_redirect!
    assert_response :success
  end

  test "a student or a team member receives 403; a visitor goes to the sign-in page" do
    get teacher_classrooms_path
    assert_redirected_to new_session_path

    sign_in_as create_student(classroom: @sixth1)
    get teacher_classrooms_path
    assert_response :forbidden
    post teacher_onboarding_path
    assert_response :forbidden
  end

  test "« Terminer » with declared classrooms stores the onboarding and lands on /teachers" do
    declare(@sixth1, @third_b)
    sign_in_as @teacher

    post teacher_onboarding_path

    assert_redirected_to teacher_home_path
    assert_response :see_other
    assert_equal onboarding("completed"), flash[:notice]
    assert onboarded?(@teacher)
    assert_equal [ @sixth1.id, @third_b.id ].sort, Orm::TeacherClassroom.where(teacher: @teacher).pluck(:classroom_id).sort

    sign_out
    post session_path, params: { session: { contact: @teacher.contact, pin: "2468" } }
    assert_redirected_to teacher_home_path
  end

  test "« Terminer » without any classroom: the page again in 422 with the message, nothing stored" do
    sign_in_as @teacher

    post teacher_onboarding_path

    assert_response :unprocessable_entity
    assert_select "#teacher-onboarding-error[role=alert]", text: onboarding("no_classroom")
    assert_select "#teacher-onboarding-form button[aria-describedby=teacher-onboarding-error]"
    assert_select "h1", tl("index.title")
    assert_not onboarded?(@teacher)
  end

  test "non-regression: declared classrooms do not make an onboarding, and withdrawing them all does not undo one" do
    declare(@sixth1)
    post session_path, params: { session: { contact: @teacher.contact, pin: "2468" } }
    assert_redirected_to teacher_classrooms_path
    sign_out

    onboarded = create_teacher(school: @school)
    post session_path, params: { session: { contact: onboarded.contact, pin: "2468" } }
    assert_redirected_to teacher_home_path
  end
end

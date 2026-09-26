require "test_helper"

# TR-05, TR-02 (UDR-0026): the teacher home. The old feed raised NameError as soon as the teacher had a classroom, a
# teacher without a school bounced between / and /teachers/classrooms, and a « Prepa » amount in FCFA sat on a dead block.
class Classroom::TeacherHomesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @svt = create_material(name: "SVT", category: "science")
    @classroom = create_classroom(school: @school, level: create_level(name: "Tle"), name: "Tle D 1")
    @teacher = create_teacher(school: @school, material: @svt, classrooms: [ @classroom ], first_name: "Yao")
  end

  def tl(key, **) = I18n.t("classroom.teacher_homes.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/

  test "a configured teacher sees their classrooms, each with its headcount, active assignments and average score" do
    exercise = create_exercise(essential: create_essential(course: create_course(material: @svt)))
    2.times { create_exercise_session(student: create_student(classroom: @classroom), exercise:, status: "completed", score_percent: 70) }
    create_assignment(classroom: @classroom, assignable: exercise, by: @teacher)
    sign_in_as @teacher

    get teacher_home_path

    assert_response :success
    assert_select "h1", text: including(tl("show.greeting", name: "Yao"))
    assert_select "main", text: including("Lycée Classique d'Abidjan")
    assert_select "main", text: including("SVT")
    assert_select "#teacher_home_classrooms li#classroom_#{@classroom.public_id}" do
      assert_select "a[href='#{classroom_path(@classroom.public_id)}']", text: including("Tle D 1")
      assert_select "*", text: including(tl("classroom_card.students", count: 2))
      assert_select "*", text: including(tl("classroom_card.assignments", count: 1))
      assert_select "*", text: including(tl("classroom_card.score", score: 70))
    end
    assert_select "#teacher_home_classrooms a[href='#{teacher_classrooms_path}']", text: including(tl("show.edit_classrooms"))
  end

  test "a classroom without a completed session says so, without a score" do
    sign_in_as @teacher

    get teacher_home_path

    assert_select "li#classroom_#{@classroom.public_id}" do
      assert_select "*", text: including(tl("classroom_card.no_score"))
      assert_select "*", text: including(tl("classroom_card.students", count: 0))
      assert_select "*", text: including(tl("classroom_card.assignments", count: 0))
    end
  end

  test "no declared classroom: the empty state, and the link to edit the classrooms remains" do
    sign_in_as create_teacher(school: @school)

    get teacher_home_path

    assert_select "#teacher_home_classrooms", text: including(tl("show.classrooms_empty"))
    assert_select "#teacher_home_classrooms li", 0
    assert_select "#teacher_home_classrooms a[href='#{teacher_classrooms_path}']"
  end

  test "the activity is announced for later, without any link, and the courses lead to the catalog" do
    sign_in_as @teacher

    get teacher_home_path

    assert_select "#teacher_home_activity", text: including(tl("show.activity_soon"))
    assert_select "#teacher_home_activity a", 0
    assert_select "a#teacher_home_courses[href='#{courses_path}']"
  end

  test "TR-06 dropped: no « Prepa » amount nor FCFA" do
    sign_in_as @teacher

    get teacher_home_path

    assert_no_match(/prepa|fcfa/i, response.body)
  end

  test "a teacher whose setup is not finished: one redirection, to the classroom declaration, which answers" do
    sign_in_as create_teacher(school: @school, onboarded: false)

    get teacher_home_path

    assert_redirected_to teacher_classrooms_path
    follow_redirect!
    assert_response :success
  end

  test "a teacher without a primary school: one redirection, to the exit screen, which answers" do
    teacher = create_teacher(school: @school)
    Orm::TeacherSchool.where(teacher:).delete_all
    sign_in_as teacher

    get teacher_home_path

    assert_redirected_to pending_account_path
    follow_redirect!
    assert_response :success
  end

  test "a student and the team receive 403" do
    [ create_student(classroom: @classroom), create_team_member ].each do |user|
      sign_in_as user

      get teacher_home_path

      assert_response :forbidden
      sign_out
    end
  end
end

require "test_helper"

# TR-05, TR-02 (UDR-0026): the teacher home. The old feed raised NameError as soon as the teacher had a classroom, a
# teacher without a school bounced between / and /teachers/classrooms, and a « Prepa » amount in FCFA sat on a dead block.
# RE-11 to RE-13, RE-16 to RE-18, RE-28 (UDR-0069): « Mes classes » (⋮ menu), « Cours » (one bubble per level taught),
# « Activités ».
class Classroom::TeacherHomesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @svt = create_material(name: "SVT", category: "science")
    @tle = create_level(name: "Tle")
    @classroom = create_classroom(school: @school, level: @tle, name: "Tle D 1")
    @teacher = create_teacher(school: @school, material: @svt, classrooms: [ @classroom ], first_name: "Yao")
  end

  def tl(key, **) = I18n.t("classroom.teacher_homes.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def illustration(file) = ActionController::Base.helpers.image_path("subjects/#{file}.svg")
  def bubble_ids = css_select("#teacher_home_course_levels li a").map { it["id"] }

  # Koffi (RE-13): Maths in 3ème 1, 3ème 2, 1ère A and Tle D, and an archived 4ème.
  def maths_teacher
    third, fourth, first = { "3ème" => 4, "4ème" => 3, "1ère" => 6 }.map { |name, position| create_level(name:, position:) }
    classrooms = [ create_classroom(school: @school, level: @tle, series: create_series(name: "D"), name: "Tle D 2"),
                   create_classroom(school: @school, level: third, name: "3ème 2"),
                   create_classroom(school: @school, level: first, series: create_series(name: "A"), name: "1ère A 1"),
                   create_classroom(school: @school, level: third, name: "3ème 1"),
                   create_classroom(school: @school, level: fourth, name: "4ème 1", status: "archived") ]
    create_teacher(school: @school, material: create_material(name: "Mathématiques"), classrooms:)
  end

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

  test "RE-11: « Mes classes », « Cours », then « Activités », announced for later and without any link" do
    sign_in_as @teacher

    get teacher_home_path

    assert_equal %w[teacher_home_classrooms teacher_home_courses teacher_home_activity],
                 css_select("#teacher_home_classrooms, #teacher_home_courses, #teacher_home_activity").map { it["id"] }
    assert_select "#teacher_home_classrooms h2", text: "Mes classes"
    assert_select "#teacher_home_courses h2", text: "Cours"
    assert_select "#teacher_home_activity h2", text: "Activités"
    assert_select "#teacher_home_activity", text: including(tl("show.activity_soon"))
    assert_select "#teacher_home_activity a", 0
    assert_no_match "Activité de vos classes", response.body
  end

  test "RE-12: « Modifier mes classes » lives in the « Actions sur mes classes » menu, and the card has no footer" do
    sign_in_as @teacher

    get teacher_home_path

    assert_select "#teacher_home_classrooms button[aria-haspopup=menu][aria-controls=teacher-classrooms-menu]" \
                  "[aria-label='Actions sur mes classes']"
    assert_select "#teacher_home_classrooms a[href='#{teacher_classrooms_path}']", count: 1
    assert_select "#teacher-classrooms-menu[role=menu] a[role=menuitem][href='#{teacher_classrooms_path}']",
                  text: "Modifier mes classes"
  end

  test "RE-12: no declared classroom: the empty state, and the menu to edit the classrooms remains" do
    sign_in_as create_teacher(school: @school)

    get teacher_home_path

    assert_select "#teacher_home_classrooms", text: including(tl("show.classrooms_empty"))
    assert_select "#teacher_home_classrooms li", 0
    assert_select "#teacher-classrooms-menu a[role=menuitem][href='#{teacher_classrooms_path}']", text: "Modifier mes classes"
  end

  test "RE-13: one bubble per level and series taught, in order, with the Maths drawing, then « Inviter »" do
    sign_in_as maths_teacher

    get teacher_home_path

    assert_select "#teacher_home_courses", text: including("Les cours de vos niveaux en Mathématiques")
    assert_select "nav#teacher_home_course_levels[aria-label='Vos niveaux et actions'] > ul.grid.grid-cols-4"
    assert_equal %w[course_level_3eme course_level_1ere_a course_level_tle_d course_level_invite], bubble_ids
    { "3eme" => [ "3ème", courses_path(level: "3eme", material: "mathematiques") ],
      "1ere_a" => [ "1ère A", courses_path(level: "1ere", series: "a", material: "mathematiques") ],
      "tle_d" => [ "Tle D", courses_path(level: "tle", series: "d", material: "mathematiques") ] }.each do |key, (label, href)|
      assert_select "a#course_level_#{key}[href='#{href}']", text: including(label) do
        assert_select "img[src='#{illustration('maths')}'][alt='']"
        assert_select ".sr-only", text: ", cours de Mathématiques"
      end
    end
    assert_select "a#course_level_invite[href='#{teacher_invite_path}']", text: "Inviter" do
      assert_select "img[src='#{illustration('inviter')}']"
    end
    assert_select "#teacher_home_course_levels", text: including("4ème"), count: 0
    assert_select "#teacher_home_courses_empty", 0
    assert_select "#teacher_home_courses a[href='#{courses_path}']", text: including("Voir tout le catalogue")
    assert_select "a#teacher_home_courses", 0
  end

  test "RE-16: a teacher without a classroom this year has no level bubble, a hint, « Inviter » and the full catalog" do
    sign_in_as create_teacher(school: @school, material: @svt)

    get teacher_home_path

    assert_select "#teacher_home_courses_empty", text: "Déclarez vos classes pour retrouver ici les cours de vos niveaux."
    assert_equal %w[course_level_invite], bubble_ids
    assert_select "#teacher_home_courses a[href='#{courses_path}']", text: including("Voir tout le catalogue")
  end

  test "RE-17: a subject without a drawing of its own gets the generic one" do
    english = create_material(name: "Anglais", category: "literature")
    sign_in_as create_teacher(school: @school, material: english, classrooms: [ @classroom ])

    get teacher_home_path

    assert_select "a#course_level_tle[href='#{courses_path(level: 'tle', material: english.slug)}']" do
      assert_select "img[src='#{illustration('generique')}']"
      assert_select ".sr-only", text: ", cours de Anglais"
    end
  end

  test "RE-18: a teacher whose primary school is inactive sees neither the « Inviter » bubble nor the invitation block" do
    @school.update!(status: "inactive")
    sign_in_as @teacher

    get teacher_home_path

    assert_response :success
    assert_equal %w[course_level_tle], bubble_ids
    assert_select "#course_level_invite", 0
    assert_select "#invite_colleagues", 0
  end

  test "RE-20: the invitation block stays on the home, inside a wrapper hidden from lg up" do
    sign_in_as @teacher

    get teacher_home_path

    assert_select "div.lg\\:hidden > #invite_colleagues"
  end

  test "RE-28, TR-06 dropped: no « Versement », no « Prepa » amount nor FCFA" do
    sign_in_as maths_teacher

    get teacher_home_path

    # « Téléversement » is not a « Versement »: the word alone.
    assert_no_match(/(?<![[:alpha:]])versement|prepa|fcfa/i, response.body)
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

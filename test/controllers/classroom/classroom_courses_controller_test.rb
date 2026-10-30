require "test_helper"

# CL-11, UDR-0028, UDR-0139 : the teacher opens a lesson from their classroom and sees its two sections, « Fiche de révision » and
# « Prépare interros », with the assignment toggles of THIS classroom only (CA-06, CA-07, CA-10).
class Classroom::ClassroomCoursesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Génétique et évolution", material: create_material(name: "SVT", category: "science"),
                            subtitle: "Du gène à l'espèce")
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée Classique"), level: @course.level,
                                  series: @course.series)
    @teacher = create_teacher(classrooms: [ @classroom ])
    @meiose = create_essential(course: @course, name: "La méiose", position: 1)
    @mitose = create_essential(course: @course, name: "La mitose", position: 2)
    @ex_meiose = create_exercise(essential: @meiose, title: "Exercice méiose")
    @ex_mitose = create_exercise(essential: @mitose, title: "Exercice mitose")
    @ex_wide = create_lesson_wide_exercise(course: @course, title: "Exercice de toute la leçon")
  end

  def tl(key, **) = I18n.t("classroom.classroom_courses.show.#{key}", **)
  def toggle(key) = I18n.t("classroom.assignments.toggle.#{key}")
  def including(text) = /#{Regexp.escape(text)}/
  def toggle_id(classroom, exercise) = "assignment_#{classroom.public_id}_Exercise_#{exercise.public_id}"
  def no_toggle = assert_select("[id^=assignment_], form[action*=assignments]", 0)

  test "the teacher sees the header and both sections, exercises grouped by sheet then the whole lesson" do
    sign_in_as @teacher

    get classroom_course_path(@classroom.public_id, @course.slug)

    assert_response :success
    assert_select "h1", text: "Génétique et évolution"
    assert_select "a[href='#{classroom_path(@classroom.public_id)}']", text: including("Tle D 1")
    assert_select "#fiche-de-revision h2", text: "Fiche de révision"
    assert_select "#prepare-interros h2", text: "Prépare interros"
    assert_select "#prepare-interros ul#prepare-interros-grid > li > span#notion-#{@meiose.slug}[aria-label=?]", "La méiose"
    assert_select "#prepare-interros #notion-#{@mitose.slug}", 1
    assert_select "#prepare-interros ul#prepare-interros-grid > li > span#toute-la-lecon[aria-label=?]", tl("lesson_wide_title")
    assert_select "#prepare-interros h3", text: "La méiose", count: 0
    assert_select "#prepare-interros h3", text: tl("lesson_wide_title"), count: 0
    assert_select "#prepare-interros li#exercise-#{@ex_wide.public_id}"
    assert_select "#prepare-interros li#exercise-#{@ex_meiose.public_id} a[href='#{exercise_path(@ex_meiose.public_id)}']"
    # CA-05 : aucun ancien intitulé.
    assert_no_match(/Révisions de la leçon|Fiche de cours/, response.body)
  end

  # UDR-0139 §3.4 : « Assigner » pour cette classe seulement, jamais pour une autre classe de l'enseignant.
  test "the toggles are those of this classroom only, the first « Assigner » being filled" do
    other = create_classroom(name: "Tle D 2", level: @course.level, series: @course.series, school: @classroom.school)
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom: other)
    assignment = create_assignment(classroom: @classroom, assignable: @ex_mitose, by: @teacher, due_on: Date.current + 2)
    sign_in_as @teacher

    get classroom_course_path(@classroom.public_id, @course.slug)

    assert_select "##{toggle_id(@classroom, @ex_meiose)}", text: including(toggle("assign"))
    assert_select "##{toggle_id(@classroom, @ex_wide)}"
    assert_select "##{toggle_id(@classroom, @ex_mitose)}", text: including(toggle("assigned"))
    assert_select "form[action='#{archive_assignment_path(assignment.public_id)}']"
    assert_select "[id^='assignment_#{other.public_id}']", 0
    assert_select ".ui-button-primary", 1
    assert_select "##{toggle_id(@classroom, @ex_meiose)} .ui-button-primary"
  end

  # UDR-0145 §3.2 ter : les évaluations vont dans « Prépare devoirs », les fixations dans « Prépare interros », jamais l'inverse.
  test "evaluations go to « Prépare devoirs » with their toggles, fixations stay in « Prépare interros »" do
    eval_mitose = create_exercise(essential: @mitose, title: "Devoir mitose", exercise_type: "evaluation")
    eval_wide = create_lesson_wide_exercise(course: @course, title: "Devoir de la leçon", exercise_type: "evaluation")
    sign_in_as @teacher

    get classroom_course_path(@classroom.public_id, @course.slug)

    assert_select "section#prepare-devoirs[aria-labelledby=prepare_devoirs_title] h2#prepare_devoirs_title", text: tl("prepare_devoirs_title")
    assert_select "section#prepare-devoirs", text: including(tl("prepare_devoirs_intro"))
    assert_select "ul#prepare-devoirs-grid li[id^=exercise-]", 2
    assert_select "ul#prepare-devoirs-grid li#exercise-#{eval_mitose.public_id}"
    assert_select "ul#prepare-devoirs-grid li#exercise-#{eval_wide.public_id}"
    assert_select "ul#prepare-devoirs-grid li#exercise-#{@ex_meiose.public_id}", 0
    assert_select "ul#prepare-interros-grid li#exercise-#{eval_mitose.public_id}", 0
    assert_select "ul#prepare-interros-grid li#exercise-#{eval_wide.public_id}", 0
    assert_select "ul#prepare-interros-grid li#exercise-#{@ex_meiose.public_id}"
    assert_select "ul#prepare-devoirs-grid li#exercise-#{eval_mitose.public_id} ##{toggle_id(@classroom, eval_mitose)}"
    assert_select ".ui-button-primary", 1
    # Chaque repère n'existe qu'une fois : « notion-mitose » a déjà sa fixation, « toute-la-lecon » la sienne.
    assert_select "##{"notion-#{@mitose.slug}"}", 1
    assert_select "#toute-la-lecon", 1
    assert_select "ul#prepare-devoirs-grid span[id]", 0
  end

  test "a notion with only an evaluation carries its anchor in « Prépare devoirs », which is absent without evaluation" do
    sign_in_as @teacher
    get classroom_course_path(@classroom.public_id, @course.slug)
    assert_select "section#prepare-devoirs", 0

    @ex_mitose.update!(exercise_type: "evaluation")
    get classroom_course_path(@classroom.public_id, @course.slug)

    assert_select "##{"notion-#{@mitose.slug}"}", 1
    assert_select "ul#prepare-devoirs-grid > li > span#notion-#{@mitose.slug}"
    assert_select "ul#prepare-interros-grid span#notion-#{@mitose.slug}", 0
  end

  # UDR-0013 : une leçon d'un autre niveau que la classe, atteinte par l'URL, n'existe pas sur la page de la classe.
  test "a lesson of another level than the classroom is a 404" do
    classroom = create_classroom(name: "6ème 1")
    sign_in_as create_teacher(classrooms: [ classroom ])

    get classroom_course_path(classroom.public_id, @course.slug)

    assert_response :not_found
  end

  # CA-10 : une leçon sans exercice.
  test "a lesson without exercise shows the empty state and no toggle" do
    course = create_course(level: @course.level, series: @course.series)
    sign_in_as @teacher

    get classroom_course_path(@classroom.public_id, course.slug)

    assert_response :success
    assert_select "#prepare-interros", text: including(tl("exercises_empty"))
    no_toggle
  end

  test "an unpublished exercise is not listed" do
    create_exercise(essential: @meiose, title: "Brouillon", status: "draft")
    sign_in_as @teacher

    get classroom_course_path(@classroom.public_id, @course.slug)

    assert_no_match "Brouillon", response.body
  end

  # vie-de-la-classe, Lot C (Q8) : une classe archivée n'a plus de page, même pour son enseignant.
  test "an archived classroom: 404 for its teacher" do
    archived = create_classroom(status: "archived")
    teacher = create_teacher(classrooms: [ archived ])
    sign_in_as teacher

    get classroom_course_path(archived.public_id, @course.slug)

    assert_response :not_found
    assert_no_match "Génétique et évolution", response.body
  end

  test "the team reads the page, with the status of each exercise and without any toggle" do
    sign_in_as create_team_member

    get classroom_course_path(@classroom.public_id, @course.slug)

    assert_response :success
    assert_select "#prepare-interros li[id^=exercise-]", 3
    assert_select "#prepare-interros li#exercise-#{@ex_meiose.public_id}", text: including(I18n.t("catalog.content_status.published"))
    no_toggle
  end

  test "another teacher or a student of the classroom receives 403, without the course" do
    [ create_teacher, create_student(classroom: @classroom) ].each do |user|
      sign_in_as user

      get classroom_course_path(@classroom.public_id, @course.slug)

      assert_response :forbidden
      assert_no_match "Génétique et évolution", response.body
      sign_out
    end
  end

  test "an unknown classroom, an unknown or unpublished course: 404" do
    draft = create_course(status: "draft")
    sign_in_as @teacher

    get classroom_course_path("inconnue", @course.slug)
    assert_response :not_found
    [ "inconnu", draft.slug ].each do |slug|
      get classroom_course_path(@classroom.public_id, slug)
      assert_response :not_found
    end
  end
end

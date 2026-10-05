require "test_helper"

# CL-22, CL-10 (volet élève) — UDR-0011. « Ma classe » : la classe principale de l'élève, le code de la classe en
# majuscules. Jamais la liste nominative : aucun nom de camarade dans la page. Amendement du 2026-10-02 (UDR-0057) : ni
# sous-titre ni aide permanente, aucune action principale. UDR-0076 §3.2 : sous la classe, les cours des exercices
# assignés en carrousel, les exercices assignés pas encore faits, puis les exercices traités au meilleur score.
class Classroom::StudentClassroomsControllerTest < ActionDispatch::IntegrationTest
  # SobrietyAssertions::PRIMARY_ACTION, read here by assert_select: the browser assertions are for system tests.
  PRIMARY_ACTION = SobrietyAssertions::PRIMARY_ACTION.split(", ").map { "#main #{it}" }.join(", ").freeze

  setup do
    @classroom = create_classroom(name: "Tle D 1", join_code: "kfm37", school: create_school(name: "Lycée Classique"),
                                  level: create_level(name: "Tle"), series: create_series(name: "D"), school_year: "2026-2027")
    @student = create_student(classroom: @classroom, first_name: "Aya", last_name: "Kouassi")
  end

  def tl(key, **) = I18n.t("classroom.student_classrooms.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/

  test "the student sees their classroom and its code in capitals, and the name of no other student" do
    create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yapo")
    sign_in_as @student

    get student_classroom_path

    assert_response :success
    assert_select "title", text: including(tl("show.page_title"))
    assert_select "h1", text: tl("show.title")
    assert_select "h1 + p", 0
    assert_select "#student_classroom_header" do
      assert_select "h2", text: "Tle D 1"
      assert_select "*", text: "Tle · D"
      assert_select "*", text: "Lycée Classique"
      assert_select "*", text: "2026-2027"
      assert_select "#student_classroom_join_code[aria-labelledby=student_classroom_join_code_label]", text: "KFM37"
      assert_select "#student_classroom_join_code_label", text: tl("show.join_code")
      assert_select "details summary", text: I18n.t("components.info_tip.label", label: tl("show.join_code"))
      assert_select "details div", text: tl("show.join_code_info_tip")
    end
    assert_no_match "kfm37", response.body
    assert_no_match "Yapo", response.body
    assert_no_match "Koffi", response.body
    assert_select "a[href='#{student_classroom_path}'][aria-current=page]"
  end

  def course_named(name, material: svt)
    create_course(name:, material:, level: @classroom.level, series: @classroom.series)
  end

  def svt = @svt ||= create_material(name: "SVT", category: "science")

  def assign(title, course:, at: 1.hour.ago)
    create_exercise(essential: create_essential(course:), title:).tap do
      create_assignment(classroom: @classroom, assignable: it, assigned_at: at)
    end
  end

  def complete(exercise, score, at:)
    create_exercise_session(student: @student, exercise:, status: "completed", score_percent: score).tap { it.update!(completed_at: at) }
  end

  # UDR-0076 §3.2 : la classe, puis « Cours assignés », « Exercices assignés », « Exercices traités ».
  test "below the classroom: the assigned courses, the assigned exercises, then the treated exercises" do
    sign_in_as @student

    get student_classroom_path

    assert_equal %w[student_classroom_header student_classroom_courses student_classroom_assigned student_classroom_treated],
                 css_select("#main .grid > [id]").map { it["id"] }
  end

  # CA-4 : les cours des exercices assignés, en bande défilante, chacun vers sa page ; un cours sans exercice assigné n'y est pas.
  test "the assigned courses in a carousel band: one card per course of an assigned exercise, to the course page" do
    genetics = course_named("Génétique")
    functions = course_named("Fonctions", material: create_material(name: "Mathématiques"))
    assign("Méiose", course: genetics, at: 2.hours.ago)
    assign("Dérivées", course: functions, at: 1.hour.ago)
    course_named("Sans exercice")
    sign_in_as @student

    get student_classroom_path

    assert_select "#student_classroom_courses" do
      assert_select "h2", text: tl("show.courses_title")
      assert_select "[data-controller='communication--carousel'] ul[data-communication--carousel-target=track][aria-label=?]",
                    tl("show.courses_title")
      assert_select "li a[href=?]", course_path(functions.slug), text: including("Fonctions")
      assert_select "li a[href=?]", course_path(genetics.slug), text: including(tl("course_card.assigned", count: 1))
      assert_select "[data-communication--carousel-target=dot]", 2
      assert_select "*", text: tl("show.courses_count", count: 2)
    end
    assert_equal [ "course_#{functions.slug}", "course_#{genetics.slug}" ], css_select("#student_classroom_courses li[id]").map { it["id"] }
    assert_no_match "Sans exercice", response.body
  end

  # CA-5 : 3 lignes visibles, les suivantes masquées, « Voir plus » ; un exercice déjà fait n'est pas « assigné ».
  test "the assigned exercises not done yet: 3 lines, then « Voir plus », each line to its exercise, without a button" do
    genetics = course_named("Génétique")
    exercises = (1..4).map { assign("Exercice #{it}", course: genetics, at: it.hours.ago) }
    complete(assign("Déjà fait", course: genetics, at: 1.minute.ago), 90, at: 1.minute.ago)
    sign_in_as @student

    get student_classroom_path

    assert_select "#student_classroom_assigned[data-controller=reveal]" do
      assert_select "li", 4
      assert_select "li:not([hidden])", 3
      assert_select "li[hidden][data-reveal-target=item]", 1
      assert_select "li a[href=?]", exercise_path(exercises.first.public_id), text: including("Exercice 1")
      assert_select "button[data-action='reveal#more']", text: I18n.t("components.reveal.more")
      assert_select "form, input[type=submit]", 0
    end
    assert_select "#student_classroom_assigned", text: including("Déjà fait"), count: 0
  end

  # CA-6 : une ligne par exercice traité, au meilleur score sur 20, vers le résultat de sa dernière session.
  test "the treated exercises: best grade out of 20, newest first, to the result of the last session, 3 lines then « Voir plus »" do
    genetics = course_named("Génétique")
    redone = create_exercise(essential: create_essential(course: genetics), title: "Refait")
    complete(redone, 40, at: 3.hours.ago)
    last = complete(redone, 80, at: 10.minutes.ago)
    (1..3).each { complete(create_exercise(essential: create_essential(course: genetics), title: "Traité #{it}"), 50, at: it.days.ago) }
    complete(create_exercise(essential: create_essential(course: genetics), title: "Autre élève"), 100, at: 1.minute.ago)
      .update!(student: create_student(classroom: @classroom))
    sign_in_as @student

    get student_classroom_path

    assert_select "#student_classroom_treated[data-controller=reveal]" do
      assert_select "li", 4
      assert_select "li:not([hidden])", 3
      assert_select "li:first-child a[href=?]", exercise_session_result_path(last.public_id) do
        assert_select "*", text: "16/20"
        assert_select "*", text: including("Refait")
        assert_select "*", text: including(tl("treated_exercise.best"))
      end
      assert_select "button[data-action='reveal#more']"
    end
    assert_no_match "Autre élève", response.body
  end

  test "nothing assigned, nothing treated: the empty state of each section" do
    sign_in_as @student

    get student_classroom_path

    assert_select "#student_classroom_courses", text: including(tl("show.courses_empty"))
    assert_select "#student_classroom_assigned", text: including(tl("show.assigned_empty"))
    assert_select "#student_classroom_treated", text: including(tl("show.treated_empty"))
    assert_select "#main [data-controller=reveal]", 0
  end

  # UDR-0057 R1 : « Ma classe » se lit, elle n'a pas d'action principale, même avec des exercices à faire.
  test "UDR-0057: no primary action, even with exercises to do" do
    assign("Méiose", course: course_named("Génétique"))
    sign_in_as @student

    get student_classroom_path

    assert_select PRIMARY_ACTION, 0
  end

  # ADR-0076 §4.1 (CA-8) : la page est personnelle, jamais dans un cache partagé ; ADR-0067 : un nombre fixe de requêtes.
  test "ADR-0076 — Ma classe is never public in a cache, and costs one round trip without a lazy frame" do
    sign_in_as @student

    get student_classroom_path

    assert_match(/private|no-store/, response.headers["Cache-Control"])
    assert_no_match(/public/, response.headers["Cache-Control"])
    assert_select "turbo-frame[src]", 0
  end

  test "a classroom without series or code: the level alone and the empty state of the code" do
    classroom = create_classroom(level: create_level(name: "6ème"), join_code: nil)
    sign_in_as create_student(classroom:)

    get student_classroom_path

    assert_select "#student_classroom_header", text: including("6ème")
    assert_select "#student_classroom_header", text: including(" · "), count: 0
    assert_select "#student_classroom_header", text: including(tl("show.no_join_code"))
    assert_select "#student_classroom_join_code", 0
  end

  test "CL-10: the student receives 403 on the teacher page of their own classroom" do
    sign_in_as @student

    get classroom_path(@classroom.public_id)

    assert_response :forbidden
    assert_no_match "KFM37", response.body
  end

  test "a student without an active classroom: one redirection, to a page that answers" do
    sign_in_as create_student

    get student_classroom_path

    assert_redirected_to pending_account_path
    follow_redirect!
    assert_response :success
  end

  test "a teacher and the team receive 403" do
    [ create_teacher, create_team_member ].each do |user|
      sign_in_as user

      get student_classroom_path

      assert_response :forbidden
      sign_out
    end
  end
end

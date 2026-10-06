require "test_helper"

# CL-22, CL-10 (volet élève) — UDR-0011. « Ma classe » : la classe principale de l'élève, le code de la classe en
# majuscules. Jamais la liste nominative : aucun nom de camarade dans la page. Amendement du 2026-10-02 (UDR-0057) : ni
# sous-titre ni aide permanente, aucune action principale. Amendement du 2026-10-02 (ADR-0072) : la carte « Cours
# assignés » est retirée, un cours ne s'assignant plus.
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

  # UDR-0011, amendement du 2026-10-02 (ADR-0072) : la carte resterait toujours vide ; elle est retirée.
  test "no « Cours assignés » card, even with an assigned exercise: the classroom card alone" do
    course = create_course(name: "Génétique", level: @classroom.level, series: @classroom.series)
    create_assignment(classroom: @classroom, assignable: create_exercise(essential: create_essential(course:)))
    sign_in_as @student

    get student_classroom_path

    assert_response :success
    assert_select "#student_classroom_header", text: including("Tle · D")
    assert_select "#student_classroom_courses", 0
    assert_no_match(/Cours assignés|Aucun cours assigné|Génétique/, response.body)
    assert_select "#main a[href='#{course_path(course.slug)}']", 0
  end

  test "UDR-0057: no primary action, and nothing to reveal" do
    sign_in_as @student

    get student_classroom_path

    assert_select PRIMARY_ACTION, 0
    assert_select "#main [data-controller=reveal]", 0
  end

  test "a classroom without series or code: the level alone and the empty state of the code" do
    classroom = create_classroom(level: create_level(name: "6ème"), join_code: nil)
    sign_in_as create_student(classroom:)

    get student_classroom_path

    assert_select "#student_classroom_header", text: including("6ème")
    assert_select "#student_classroom_header", text: including(" · "), count: 0
    assert_select "#student_classroom_header", text: including(tl("show.no_join_code"))
    assert_select "#student_classroom_join_code", 0
    assert_select "#student_classroom_courses", 0
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

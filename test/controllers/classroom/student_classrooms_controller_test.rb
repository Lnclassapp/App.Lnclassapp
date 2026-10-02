require "test_helper"

# CL-22, CL-10 (volet élève) — UDR-0011. « Ma classe » : la classe principale de l'élève, le code de la classe en
# majuscules, les cours assignés actifs et publiés. Jamais la liste nominative : aucun nom de camarade dans la page.
# Amendement du 2026-10-02 (UDR-0057) : ni sous-titre ni aide permanente, une ligne de cours « nom, matière », 3 lignes
# puis « Voir plus », aucune action principale.
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

  test "each assigned course: its name, its subject and a link to the course, nothing else" do
    course = create_course(name: "Génétique", subtitle: "Du gène au caractère", level: @classroom.level,
                           series: @classroom.series, material: create_material(name: "SVT", category: "science"))
    create_essential(course:)
    create_assignment(classroom: @classroom, assignable: course)
    create_assignment(classroom: @classroom, assignable: create_course(name: "Retiré"), status: "archived")
    create_assignment(classroom: @classroom, assignable: create_course(name: "Archivé", status: "archived"))
    sign_in_as @student

    get student_classroom_path

    assert_select "#student_classroom_header", text: including("Tle · D")
    assert_select "#student_classroom_courses" do
      assert_select "*", text: tl("show.courses_count", count: 1)
      assert_select "li", 1
      assert_select "li#course_#{course.slug}" do
        assert_select "a[href='#{course_path(course.slug)}']", text: including("Génétique")
        assert_select "a p.truncate", text: "Génétique"
        assert_select "*", text: "SVT"
      end
      assert_select "li", text: including("Du gène au caractère"), count: 0
      assert_select "li", text: including("Tle · D"), count: 0
      assert_select "li", text: including("fiche essentielle"), count: 0
      assert_select "button", 0
    end
    assert_no_match "Les cours que tes enseignants ont assignés", response.body
    assert_no_match "Retiré", response.body
    assert_no_match "Archivé", response.body
  end

  test "UDR-0057: four assigned courses, three shown, the fourth behind « Voir plus », and no primary action" do
    %w[Algèbre Biologie Chimie Dynamique].each do |name|
      create_assignment(classroom: @classroom, assignable: create_course(name:, level: @classroom.level, series: @classroom.series))
    end
    sign_in_as @student

    get student_classroom_path

    assert_select PRIMARY_ACTION, 0
    assert_select "#student_classroom_courses" do
      assert_select "*", text: tl("show.courses_count", count: 4)
      assert_select "[data-controller=reveal]" do
        assert_select "li", 4
        assert_select "li:not([hidden])", 3
        assert_select "li[hidden][data-reveal-target=item]", text: including("Dynamique")
        assert_select "button[data-reveal-target=button][data-action='reveal#more']", text: I18n.t("components.reveal.more")
        assert_select "[data-reveal-target=status][aria-live=polite]"
      end
    end
  end

  test "a classroom without series or code, without course: the level alone and the empty states" do
    classroom = create_classroom(level: create_level(name: "6ème"), join_code: nil)
    sign_in_as create_student(classroom:)

    get student_classroom_path

    assert_select "#student_classroom_header", text: including("6ème")
    assert_select "#student_classroom_header", text: including(" · "), count: 0
    assert_select "#student_classroom_header", text: including(tl("show.no_join_code"))
    assert_select "#student_classroom_join_code", 0
    assert_select "#student_classroom_courses", text: including(tl("show.courses_empty"))
    assert_select "#student_classroom_courses li", 0
    assert_select "#student_classroom_courses button", 0
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

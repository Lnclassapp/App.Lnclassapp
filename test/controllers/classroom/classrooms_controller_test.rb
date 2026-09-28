require "test_helper"

# CL-10, CL-04 (affichage), ID-15 (émission par l'enseignant) — UDR-0027. La page d'une classe, pour l'enseignant qui y
# enseigne et pour l'équipe : en-tête et code en majuscules, cours assignés, liste des élèves avec le bouton du code de
# récupération. Un élève reçoit 403 : il voit le code de sa classe sur ses propres pages, jamais la liste nominative.
class Classroom::ClassroomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school: @school, level: create_level(name: "6ème"), name: "6ème 1", join_code: "kfm37",
                                  max_students: 60)
    @teacher = create_teacher(school: @school, classrooms: [ @classroom ])
  end

  def scope = "classroom.classrooms"

  test "CP-08: « Partager sur WhatsApp » envoie le lien /c/<code> et le code, sans aucun nom d'élève (ADR-0063)" do
    create_student(classroom: @classroom, first_name: "Zoé", last_name: "Unique")
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    message = I18n.t("#{scope}.header.share_message", classroom: "6ème 1", school: "Lycée Classique d'Abidjan",
                                                       link: join_classroom_url("KFM37"), code: "KFM37")
    assert_select "#classroom_header a#classroom_whatsapp_share[href='https://wa.me/?text=#{ERB::Util.url_encode(message)}']" \
                  "[target=_blank][rel=noopener]", text: I18n.t("#{scope}.header.share_whatsapp")
    assert_no_match(/Zoé|Unique/, message)
    assert_includes message, "/c/KFM37"
  end

  test "CP-08: une classe sans code n'a rien à partager" do
    @classroom.update!(join_code: nil)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_select "#classroom_whatsapp_share", 0
  end

  test "l'enseignant de la classe voit l'en-tête, le code en majuscules, les cours assignés et ses élèves" do
    course = create_course(name: "Nombres entiers", material: create_material(name: "Mathématiques", category: "science"))
    create_essential(course:)
    create_assignment(classroom: @classroom, assignable: course, by: @teacher)
    create_assignment(classroom: @classroom, assignable: create_course(name: "Brouillon", status: "draft"), by: @teacher)
    awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba", contact: "0102030405")
    session = create_exercise_session(student: awa, status: "completed", score_percent: 85)
    create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "title", text: /6ème 1/
    within_header = "#classroom_header"
    assert_select "#{within_header} h1", text: "6ème 1"
    assert_select within_header, text: /Lycée Classique d'Abidjan/
    assert_select within_header, text: /6ème/
    assert_select within_header, text: /#{@classroom.school_year}/
    assert_select "#{within_header} [data-controller='classroom--join-code-copy']" \
                  "[data-classroom--join-code-copy-code-value='KFM37']" do
      assert_select "#classroom_join_code", text: "KFM37"
      assert_select "button[data-action='classroom--join-code-copy#copy']", text: I18n.t("#{scope}.header.copy")
      assert_select "template[data-classroom--join-code-copy-target=copied]", 1
      assert_select "template[data-classroom--join-code-copy-target=failed]", 1
    end
    assert_no_match(/kfm37/, response.body)
    assert_select "#classroom_headcount", text: I18n.t("#{scope}.header.headcount", count: 2, max: 60)

    assert_select "#assigned_courses li", 1
    assert_select "#assigned_courses a[href='#{classroom_course_path(@classroom.public_id, course.slug)}']", text: /Nombres entiers/
    assert_select "#assigned_courses", text: /Mathématiques/
    assert_select "#assigned_courses", text: /#{I18n.t("#{scope}.assigned_courses.essentials", count: 1)}/
    assert_select "#assigned_courses", text: /Brouillon/, count: 0

    assert_select "#classroom_roster li", 2
    assert_select "#student_#{awa.public_id}", text: /Awa Bamba/
    assert_select "#student_#{awa.public_id}", text: /01 02 03 04 05/
    assert_select "#student_#{awa.public_id}", text: /85 %/
    assert_select "#student_#{awa.public_id} a[href='#{exercise_session_result_path(session.public_id)}']",
                  text: I18n.t("#{scope}.roster.see_result")
    assert_select "#student_#{awa.public_id} form[method=post][action='#{account_pin_recovery_codes_path(awa.public_id)}'] " \
                  "button[type=submit]", text: I18n.t("#{scope}.roster.issue_code")
    assert_select "#classroom_roster", text: /#{I18n.t("#{scope}.roster.no_score")}/
    assert_select "#classroom_roster a", text: I18n.t("#{scope}.roster.see_result"), count: 1
  end

  test "non-régression CS#B8 : la page répond 200 avec un exercice et une fiche assignés" do
    exercise = create_exercise
    create_assignment(classroom: @classroom, assignable: exercise, by: @teacher)
    create_assignment(classroom: @classroom, assignable: exercise.essential, by: @teacher)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "#assigned_courses_empty", text: /#{I18n.t("#{scope}.assigned_courses.empty_title")}/
  end

  test "l'équipe ouvre toute classe, avec la liste des élèves" do
    student = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
    sign_in_as create_team_member

    get classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "#classroom_header", text: /KFM37/
    assert_select "#student_#{student.public_id}", text: /Awa Bamba/
  end

  test "une classe vide, sans cours ni élève, et sans code, le dit" do
    classroom = create_classroom(school: @school, join_code: nil)
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom:)
    sign_in_as @teacher

    get classroom_path(classroom.public_id)

    assert_response :success
    assert_select "#classroom_header", text: /#{I18n.t("#{scope}.header.no_join_code")}/
    assert_select "[data-controller='classroom--join-code-copy']", 0
    assert_select "#assigned_courses_empty", 1
    assert_select "#classroom_roster_empty", text: /#{I18n.t("#{scope}.roster.empty_title")}/
  end

  test "une classe archivée est signalée, et n'offre plus de code de récupération" do
    classroom = create_classroom(school: @school, status: "archived")
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom:)
    student = create_student(classroom:)
    sign_in_as @teacher

    get classroom_path(classroom.public_id)

    assert_response :success
    assert_select "#classroom_header", text: /#{I18n.t("#{scope}.header.archived")}/
    assert_select "#student_#{student.public_id}", 1
    assert_select "#classroom_roster form", 0
  end

  test "un élève, même de cette classe, reçoit 403 sans le code ni la liste" do
    student = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
    create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")
    sign_in_as student

    get classroom_path(@classroom.public_id)

    assert_response :forbidden
    assert_no_match(/kfm37|Koffi|Yao/i, response.body)
  end

  test "une classe inconnue répond 404" do
    sign_in_as @teacher

    get classroom_path("inconnue")

    assert_response :not_found
  end

  test "sans connexion, la page renvoie à la connexion" do
    get classroom_path(@classroom.public_id)

    assert_redirected_to new_session_path
  end
end

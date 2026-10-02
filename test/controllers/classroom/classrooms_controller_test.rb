require "test_helper"

# CL-10, CL-04 (affichage), ID-15 (émission par l'enseignant) — UDR-0027. La page d'une classe, pour l'enseignant qui y
# enseigne et pour l'équipe : en-tête et code en majuscules, liste des élèves avec le bouton du code de récupération.
# ADR-0072, UDR-0027 (amendée le 2026-10-02) : « Cours assignés » est retiré, un cours ne s'assignant plus. Un élève reçoit 403 : il voit le code de sa classe sur ses propres pages, jamais la liste nominative.
# Finitions (UDR-0054, FU-02, FU-07, FU-08, FU-26, FU-48) : titre, retour selon le rôle, copie par le contrôleur unique,
# « Chercher un élève » dans le frame de la liste.
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

  test "l'enseignant de la classe voit l'en-tête, le code en majuscules et ses élèves, sans « Cours assignés »" do
    course = create_course(name: "Nombres entiers", material: create_material(name: "Mathématiques", category: "science"))
    create_assignment(classroom: @classroom, assignable: create_exercise(essential: create_essential(course:)), by: @teacher)
    awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba", contact: "0102030405")
    session = create_exercise_session(student: awa, status: "completed", score_percent: 85)
    create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "title", text: "6ème 1 · Enseignant · Lnclass"
    assert_select "nav[aria-label='Retour'] a[href='#{teacher_home_path}']", text: I18n.t("#{scope}.header.back")
    within_header = "#classroom_header"
    assert_select "#{within_header} h1", text: "6ème 1"
    assert_select within_header, text: /Lycée Classique d'Abidjan/
    assert_select within_header, text: /6ème/
    assert_select within_header, text: /#{@classroom.school_year}/
    assert_select "#{within_header} #classroom_join_code", text: "KFM37"
    assert_select "#{within_header} [data-controller=clipboard][data-clipboard-text-value='KFM37']" do
      assert_select "button[hidden][data-action='clipboard#copy'][aria-label=?]", I18n.t("#{scope}.header.copy_label", code: "KFM37"),
                    text: I18n.t("#{scope}.header.copy")
      assert_select "template[data-clipboard-target=copied]", text: /#{I18n.t("shared.clipboard.copied_code")}/
      assert_select "template[data-clipboard-target=failed]", text: /#{I18n.t("shared.clipboard.failed")}/
    end
    assert_select "#{within_header} [data-controller=clipboard][data-clipboard-text-value='#{join_classroom_url('KFM37')}']" do
      assert_select "button[hidden][data-action='clipboard#copy'][aria-label=?]", I18n.t("#{scope}.header.copy_link_label"),
                    text: I18n.t("#{scope}.header.copy_link")
      assert_select "template[data-clipboard-target=copied]", text: /#{I18n.t("shared.clipboard.copied_link")}/
    end
    assert_select "[data-controller~='classroom--join-code-copy']", 0
    assert_select "#{within_header} details summary", text: /#{I18n.t("#{scope}.header.headcount_label")}/
    assert_select "#{within_header} details", text: /#{I18n.t("#{scope}.header.headcount_tip", max: 60)}/
    assert_no_match(/kfm37/, response.body)
    assert_select "#classroom_headcount", text: I18n.t("#{scope}.header.headcount", count: 2, max: 60)

    assert_select "#assigned_courses", 0
    assert_no_match(/Cours assignés|Nombres entiers/, response.body)

    assert_select "#classroom_roster form#classroom-roster-search[method=get][action='#{classroom_path(@classroom.public_id)}']" \
                  "[role=search][data-controller=search][data-turbo-frame=classroom_roster_list]" \
                  "[aria-label=?]", I18n.t("#{scope}.roster.search_label") do
      assert_select "input[type=search][name=q][data-action~='search#queue']"
      assert_select "button[type=submit][data-search-target=button]"
    end
    assert_select "#classroom_roster turbo-frame#classroom_roster_list" do
      assert_select "[aria-live=polite]", text: I18n.t("#{scope}.roster.count", count: 2)
      assert_select "li", 2
    end
    assert_select "#classroom_roster details", text: /#{I18n.t("#{scope}.roster.last_score_tip")}/
    assert_select "#classroom_roster li", 2
    assert_select "#student_#{awa.public_id}", text: /Awa Bamba/
    assert_select "#student_#{awa.public_id}", text: /01 02 03 04 05/
    assert_select "#student_#{awa.public_id}", text: /85 %/
    assert_select "#student_#{awa.public_id} a[href='#{exercise_session_result_path(session.public_id)}']",
                  text: I18n.t("#{scope}.roster.see_result")
    assert_select "#student_#{awa.public_id} form[method=post][action='#{account_pin_recovery_codes_path(awa.public_id)}']" \
                  "[data-turbo-frame=_top] button[type=submit]", text: I18n.t("#{scope}.roster.issue_code")
    assert_select "#classroom_roster", text: /#{I18n.t("#{scope}.roster.no_score")}/
    assert_select "#classroom_roster a", text: I18n.t("#{scope}.roster.see_result"), count: 1
  end

  test "non-régression CS#B8 : la page répond 200 avec un exercice assigné" do
    create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "#assigned_courses, #assigned_courses_empty", 0
    assert_no_match(/Aucun cours assigné/, response.body)
  end

  test "l'équipe ouvre toute classe, avec la liste des élèves, et revient à la fiche de l'établissement (FU-07)" do
    student = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
    sign_in_as create_team_member

    get classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "title", text: "6ème 1 · Équipe · Lnclass"
    assert_select "nav[aria-label='Retour'] a[href='#{school_path(@school.public_id)}']", text: "Lycée Classique d'Abidjan"
    assert_select "nav[aria-label='Retour'] a[href='#{teacher_home_path}']", 0
    assert_select "#classroom_header", text: /KFM37/
    assert_select "#student_#{student.public_id}", text: /Awa Bamba/
  end

  test "FU-48 : « Chercher un élève » ne garde que les élèves de la classe dont le nom correspond" do
    awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
    koffi = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")
    other = create_student(classroom: create_classroom(school: @school), first_name: "Awa", last_name: "Ailleurs")
    sign_in_as @teacher

    get classroom_path(@classroom.public_id, q: "awa")

    assert_response :success
    assert_select "#classroom_roster_title", text: I18n.t("#{scope}.roster.title", count: 2)
    assert_select "input[name=q][value=awa]"
    assert_select "#classroom_roster_list [aria-live=polite]", text: I18n.t("#{scope}.roster.count", count: 1)
    assert_select "#student_#{awa.public_id}", 1
    assert_select "#student_#{koffi.public_id}", 0
    assert_select "#student_#{other.public_id}", 0
  end

  test "FU-48 : une recherche sans résultat le dit et propose d'effacer la recherche" do
    create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
    sign_in_as @teacher

    get classroom_path(@classroom.public_id, q: "zzz")

    assert_response :success
    assert_select "#classroom_roster_list" do
      assert_select "[aria-live=polite]", text: I18n.t("#{scope}.roster.no_match")
      assert_select "li", 0
      assert_select "a[href='#{classroom_path(@classroom.public_id)}'][data-turbo-frame=_top]",
                    text: I18n.t("#{scope}.roster.clear_search")
    end
  end

  test "une classe vide, sans cours ni élève, et sans code, le dit" do
    classroom = create_classroom(school: @school, join_code: nil)
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom:)
    sign_in_as @teacher

    get classroom_path(classroom.public_id)

    assert_response :success
    assert_select "#classroom_header", text: /#{I18n.t("#{scope}.header.no_join_code")}/
    assert_select "[data-controller=clipboard]", 0
    assert_select "#assigned_courses_empty", 0
    assert_select "#classroom_roster_empty", text: /#{I18n.t("#{scope}.roster.empty_title")}/
    assert_select "#classroom-roster-search", 0
    assert_select "#classroom_roster_list", 0
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
    assert_select "#classroom_roster_list form", 0
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

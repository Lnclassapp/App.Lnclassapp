require "test_helper"

# CL-10, CL-04 (affichage), ID-15 (émission par l'enseignant) — UDR-0027. La page d'une classe, pour l'enseignant qui y
# enseigne et pour l'équipe : en-tête et code en majuscules, liste des élèves avec le bouton du code de récupération.
# ADR-0072, UDR-0027 (amendée le 2026-10-02) : « Cours assignés » est retiré, un cours ne s'assignant plus. Un élève reçoit 403 : il voit le code de sa classe sur ses propres pages, jamais la liste nominative.
# Lot E de fonctions-espace-eleve (UDR-0062 §3.4) : jours de séance de l'enseignant, exercices assignés et leurs trois
# comptes, bloc « Cours » qui rouvre le chemin vers les exercices (memo Q18).
# Finitions (UDR-0054, FU-02, FU-07, FU-08, FU-26, FU-48) : titre, retour selon le rôle, copie par le contrôleur unique,
# « Chercher un élève » dans le frame de la liste.
class Classroom::ClassroomsControllerTest < ActionDispatch::IntegrationTest
  # Le pied d'un exercice assigné (UDR-0072 §3.4) : badges à gauche, cercle à droite.
  FOOTER = "div.mt-3.flex.items-center.justify-between.border-t.border-line.pt-3".freeze

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

  test "jours de séance renseignés : « Vos jours de séance : lundi, jeudi » et « Modifier » dans le frame modal" do
    [ 4, 1 ].each { Orm::ClassroomSessionDay.create!(teacher: @teacher, classroom: @classroom, weekday: it) }
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_select "section#classroom_session_days" do
      assert_select "h2", text: I18n.t("#{scope}.session_days.title")
      assert_select "p", text: "Vos jours de séance : lundi, jeudi"
      assert_select "a[href='#{edit_classroom_session_days_path(@classroom.public_id)}'][data-turbo-frame=modal]",
                    text: I18n.t("#{scope}.session_days.edit")
    end
  end

  test "jours de séance non renseignés : le bloc le dit et propose « Renseigner »" do
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_select "section#classroom_session_days" do
      assert_select "p", text: I18n.t("#{scope}.session_days.unset")
      assert_select "a[href='#{edit_classroom_session_days_path(@classroom.public_id)}'][data-turbo-frame=modal]",
                    text: I18n.t("#{scope}.session_days.fill")
    end
  end

  test "une classe archivée montre ses jours de séance sans bouton" do
    classroom = create_classroom(school: @school, status: "archived")
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom:)
    Orm::ClassroomSessionDay.create!(teacher: @teacher, classroom:, weekday: 3)
    sign_in_as @teacher

    get classroom_path(classroom.public_id)

    assert_select "section#classroom_session_days", text: /mercredi/
    assert_select "section#classroom_session_days a", 0
  end

  test "PRD : la ligne de l'exercice dit « 18 faits, dont 3 en retard · 7 pas encore faits » et mène à son suivi" do
    exercise = create_exercise(title: "La méiose", essential: create_essential(course: create_course(
      material: create_material(name: "SVT", category: "science")
    )))
    assignment = travel_to(Time.zone.local(2026, 10, 5, 9)) do
      create_assignment(classroom: @classroom, assignable: exercise, by: @teacher, due_on: Date.new(2026, 10, 8))
    end
    { 8 => 15, 9 => 3, nil => 7 }.each do |day, count|
      count.times do
        student = create_student(classroom: @classroom)
        next unless day

        create_exercise_session(student:, exercise:, status: "completed", classroom_assignment: assignment,
                                completed_at: Time.zone.local(2026, 10, day, 10))
      end
    end
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_select "section#assigned_exercises h2", text: I18n.t("#{scope}.assigned_exercises.title")
    assert_select "#assignment_#{assignment.public_id}" do
      assert_select "a[href='#{classroom_assignment_path(@classroom.public_id, assignment.public_id)}']", text: "La méiose"
      assert_select "span", text: "SVT"
      assert_select "span", text: "Pour jeu. 8 oct."
      assert_select "p", text: "18 faits, dont 3 en retard · 7 pas encore faits"
    end
  end

  test "sans échéance ni retard, la ligne ne dit pas « en retard », et l'équipe la lit aussi" do
    exercise = create_exercise(title: "Les gamètes")
    assignment = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher)
    on_time = travel_to(Time.zone.local(2026, 10, 5, 9)) do
      create_assignment(classroom: @classroom, assignable: create_exercise(title: "À l'heure"), by: @teacher,
                        due_on: Date.new(2026, 10, 8))
    end
    student = create_student(classroom: @classroom)
    create_exercise_session(student:, exercise:, status: "completed", classroom_assignment: assignment)
    create_student(classroom: @classroom)
    sign_in_as create_team_member

    get classroom_path(@classroom.public_id)

    assert_select "#assignment_#{assignment.public_id} span", text: "Sans date limite"
    assert_select "#assignment_#{assignment.public_id} p", text: "1 fait · 1 pas encore fait"
    assert_select "#assignment_#{on_time.public_id} p", text: "0 fait · 2 pas encore faits"
    assert_no_match(/en retard/, response.body)
    assert_select "section#classroom_session_days", 0
    assert_select "#assignment_#{assignment.public_id} #{FOOTER}", text: /Pas encore lisible · 1\/2/
    assert_select "#assignment_#{on_time.public_id} #{FOOTER}", text: /Pas encore lisible · 0\/2/
  end

  # rapports-exercices, Lot A (ADR-0079, UDR-0072 §3.4) : au bord bas de chaque exercice assigné, les badges de la classe
  # à gauche et le cercle de la catégorie dominante à droite, sous FollowAssignmentPolicy comme les comptes.
  def hand_in(assignment, score_percent, student: create_student(classroom: @classroom), **attributes)
    create_exercise_session(student:, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed",
                            score_percent:, classroom_assignment: assignment, **attributes)
  end

  def assert_badges(assignment, counts)
    assert_select "#assignment_#{assignment.public_id} #{FOOTER} ul[aria-label='Badges de la classe'] li", 4 do |items|
      assert_equal counts, items.map { it.at_css(".sr-only").text }
    end
  end

  test "PRD : 6 faits à 100, 85, 72, 65, 40 et 30 sur 25 élèves donnent un badge par palier et le cercle « Acquis · 6/25 »" do
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise(title: "La méiose"), by: @teacher)
    hand_in(assignment, 100)
    hand_in(assignment, 85, student: hand_in(assignment, 40, completed_at: 1.day.ago).student)
    [ 72, 65, 40, 30 ].each { hand_in(assignment, it) }
    19.times { create_student(classroom: @classroom) }
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_badges assignment, [ "1 Bronze", "1 Argent", "1 Or", "1 Diamant" ]
    assert_select "#assignment_#{assignment.public_id} #{FOOTER} > :last-child" do
      assert_select "span.bg-success.rounded-full[aria-hidden='true']", 1
      assert_select "span.text-ink", text: "Acquis · 6/25"
    end
    assert_select "#assignment_#{assignment.public_id} p", text: "6 faits · 19 pas encore faits"
    assert_select "#assignment_#{assignment.public_id} a", 1
    assert_select "#assignment_#{assignment.public_id} #{FOOTER} a, #assignment_#{assignment.public_id} #{FOOTER} button", 0
  end

  test "PRD : sous 5 faits, le cercle est gris, « Pas encore lisible · 4/25 », et un palier vide est atténué, jamais omis" do
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher)
    4.times { hand_in(assignment, 90) }
    21.times { create_student(classroom: @classroom) }
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_badges assignment, [ "0 Bronze", "0 Argent", "4 Or", "0 Diamant" ]
    assert_select "#assignment_#{assignment.public_id} #{FOOTER}" do
      assert_select "span.bg-line.rounded-full", 1
      assert_select "span.text-ink", text: "Pas encore lisible · 4/25"
      assert_select "li:first-child span.text-line", text: "0"
    end
    assert_select "#assignment_#{assignment.public_id} p", text: "4 faits · 21 pas encore faits"
  end

  test "PRD : une autre classe, une remédiation, une session commencée, un élève parti ou anonymisé ne comptent pas" do
    exercise = create_exercise
    assignment = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher)
    present = create_student(classroom: @classroom)
    hand_in(assignment, 50, student: present)
    other = create_student(classroom: @classroom)
    hand_in(create_assignment(classroom: create_classroom(school: @school), assignable: exercise), 100, student: other)
    hand_in(create_assignment(classroom: @classroom, assignable: create_exercise(essential: exercise.essential)), 100, student: other)
    create_exercise_session(student: other, exercise:, status: "completed", score_percent: 100,
                            gap: create_gap(student: other, essential: exercise.essential))
    create_exercise_session(student: other, exercise:, classroom_assignment: assignment)
    gone = hand_in(assignment, 100).student
    Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
    hand_in(assignment, 100).student.update_columns(anonymized_at: Time.current)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_badges assignment, [ "1 Bronze", "0 Argent", "0 Or", "0 Diamant" ]
    assert_select "#assignment_#{assignment.public_id} #{FOOTER} span.text-ink", text: "Pas encore lisible · 1/2"
    assert_select "#assignment_#{assignment.public_id} p", text: "1 fait · 1 pas encore fait"
  end

  test "sans les comptes (hors FollowAssignmentPolicy), la ligne n'a ni pied, ni badges, ni cercle" do
    row = Queries::Classroom::ClassroomOverviewQuery::AssignmentRow.new(
      public_id: "a1", exercise_title: "La méiose", material_name: "SVT", material_category: "science", due_on: nil,
      counts: nil, comprehension: nil
    )

    html = ApplicationController.render(partial: "classroom/classrooms/assigned_exercises",
                                        locals: { classroom: @classroom, assignments: [ row ] })

    assert_includes html, "La méiose"
    assert_no_match(/border-t|Badges de la classe|Pas encore lisible/, html)
  end

  test "le nombre de requêtes de la page ne dépend pas du nombre d'exercices assignés" do
    exercise = create_exercise
    students = Array.new(3) { create_student(classroom: @classroom) }
    first = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher)
    students.each { hand_in(first, 80, student: it) }
    sign_in_as @teacher
    get classroom_path(@classroom.public_id)

    one = count_queries { get classroom_path(@classroom.public_id) }
    2.times do
      assignment = create_assignment(classroom: @classroom, assignable: create_exercise(essential: exercise.essential), by: @teacher)
      students.each { hand_in(assignment, 60, student: it) }
    end
    three = count_queries { get classroom_path(@classroom.public_id) }

    assert_select "#assigned_exercises #{FOOTER}", 3
    assert_equal one, three
  end

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end

  test "aucun exercice assigné : l'état vide renvoie aux cours" do
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_select "#assigned_exercises_empty", text: /#{I18n.t("#{scope}.assigned_exercises.empty_title")}/
    assert_select "#assigned_exercises_empty", text: /#{I18n.t("#{scope}.assigned_exercises.empty_description")}/
  end

  test "bloc « Cours » : les cours publiés du niveau de la classe, de la matière de l'enseignant, vers le cours dans la classe" do
    svt = create_material(name: "SVT", category: "science")
    level = create_level(name: "Tle")
    classroom = create_classroom(school: @school, level:, series: create_series(name: "D"))
    teacher = create_teacher(school: @school, material: svt, classrooms: [ classroom ])
    genetics = create_course(level:, material: svt, name: "Génétique et évolution")
    create_essential(course: genetics)
    create_course(level:, material: create_material(name: "Mathématiques"), name: "Fonctions")
    create_course(level: create_level(name: "1ère"), material: svt, name: "Autre niveau")
    sign_in_as teacher

    get classroom_path(classroom.public_id)

    assert_select "section#classroom_courses h2", text: I18n.t("#{scope}.courses.title")
    assert_select "section#classroom_courses li", 1
    assert_select "#classroom_course_#{genetics.slug}" do
      assert_select "a[href='#{classroom_course_path(classroom.public_id, genetics.slug)}']", text: "Génétique et évolution"
      assert_select "p", text: /#{I18n.t("#{scope}.courses.essentials", count: 1)}/
    end
    assert_no_match(/Fonctions|Autre niveau/, response.body)
  end

  test "bloc « Cours » sans cours publié : l'état vide" do
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_select "#classroom_courses_empty", text: /#{I18n.t("#{scope}.courses.empty_title")}/
  end

  test "la direction de l'établissement reçoit 403, sans nom ni identifiant d'élève (UDR-0052)" do
    student = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
    create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher)
    sign_in_as create_school_admin(school: @school)

    get classroom_path(@classroom.public_id)

    assert_response :forbidden
    assert_no_match(/Bamba|#{student.public_id}/, response.body)
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
    hand_in(create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher), 90, student:)
    sign_in_as student

    get classroom_path(@classroom.public_id)

    assert_response :forbidden
    assert_no_match(/kfm37|Koffi|Yao|Badges de la classe|Pas encore lisible/i, response.body)
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

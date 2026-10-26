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
    @classroom = create_classroom(school: @school, level: create_level(name: "6ème"), name: "6ème 1",
                                  max_students: 60)
    @teacher = create_teacher(school: @school, classrooms: [ @classroom ])
  end

  def scope = "classroom.classrooms"

  # ADR-0098, UDR-0111 : modifier une classe est un geste de l'équipe et de la direction, pas de l'enseignant.
  test "l'enseignant de la classe n'a ni lien ni texte « Modifier la classe »" do
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "a[href*='classroom-settings'], a[href*='classroom_settings']", count: 0
    assert_no_match(/Modifier la classe/, response.body)
  end

  test "l'enseignant de la classe voit l'en-tête, le bloc du lien et ses élèves, sans code ni « Cours assignés »" do
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
    # IL-02, UDR-0081 §3.6 : le bloc du lien a remplacé le code.
    assert_select "#{within_header} #classroom_link", 1
    assert_select "#{within_header} [id*=join_code], [data-controller~='classroom--join-code-copy']", 0
    # CA-B7 : la ligne provisoire du code est dans le bloc du lien.
    assert_select "#{within_header} #classroom_link #classroom_code", 1
    assert_select "#{within_header} details summary", text: /#{I18n.t("#{scope}.header.headcount_label")}/
    assert_select "#{within_header} details", text: /#{I18n.t("#{scope}.header.headcount_tip", max: 60)}/
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
    # IE-22 (UDR-0079 §3.8 ter) : le numéro masqué, tel que la requête le rend ; le numéro complet nulle part.
    assert_select "#student_#{awa.public_id} p[title=?]", I18n.t("#{scope}.roster.contact_masked") do
      assert_select "span[aria-hidden=true]", text: "01 •• •• •• 05"
      assert_select "span.sr-only", text: I18n.t("#{scope}.roster.contact_masked")
    end
    assert_select "#student_#{awa.public_id} p[aria-label]", 0
    assert_no_match(/0102030405|01 02 03 04 05/, response.body)
    assert_select "#classroom_roster a[href^='tel:'], #classroom_roster [data-controller~=clipboard]", 0
    assert_select "#student_#{awa.public_id}", text: /85 %/
    assert_select "#student_#{awa.public_id} a[href='#{exercise_session_result_path(session.public_id)}']",
                  text: I18n.t("#{scope}.roster.see_result")
    # rapports-de-classe (UDR-0108 §3.2, memo Q4) : la photo et le nom mènent à la fiche ; plus de menu ⋮ ni de fenêtre de
    # retrait sur la ligne : le code de récupération et le retrait sont sur la fiche.
    assert_select "#student_#{awa.public_id} a[href='#{classroom_student_path(@classroom.public_id, awa.public_id)}']" \
                  "[data-turbo-frame=_top]", text: /Awa Bamba/
    assert_select "#classroom_roster button[aria-haspopup=menu], #classroom_roster dialog, #classroom_roster [role=menu]", 0
    assert_select "#classroom_roster a[href='#{account_pin_recovery_codes_path(awa.public_id)}']", 0
    assert_select "#classroom_roster form[action='#{account_pin_recovery_codes_path(awa.public_id)}']", 0
    assert_select "#classroom_roster_more", 0
    assert_select "#classroom_roster", text: /#{I18n.t("#{scope}.roster.no_score")}/
    assert_select "#classroom_roster a", text: I18n.t("#{scope}.roster.see_result"), count: 1
  end

  test "IE-22 : quelle que soit la voie de l'enseignant, et pour l'équipe, le numéro d'un élève reste masqué" do
    student = create_student(classroom: @classroom, contact: "0701020304")
    # La connexion est limitée à 5 essais par minute : les voies qui voyaient tout sous Q22 (collègue, ancien code), une
    # voie sans preuve, et l'équipe. La requête ne lit pas la voie : elle masque pour tout lecteur (ClassroomOverviewQueryTest).
    readers = %w[colleague code standard].map do |channel|
      create_teacher(school: @school, classrooms: [ @classroom ]).tap do
        Orm::TeacherProfile.where(user_id: it.id).update_all(joined_via: channel)
      end
    end

    (readers + [ create_team_member ]).each do |reader|
      sign_in_as reader
      get classroom_path(@classroom.public_id)

      assert_response :success
      assert_select "#student_#{student.public_id}", text: /07 •• •• •• 04/
      assert_no_match(/0701020304|07 01 02 03 04/, response.body)
      assert_select "#classroom_roster a[href^='tel:']", 0
      sign_out
    end
  end

  test "jours de séance renseignés : « Vos jours de séance : lundi, jeudi » et « Modifier » dans le menu ⋮, vers le frame modal" do
    [ 4, 1 ].each { Orm::ClassroomSessionDay.create!(teacher: @teacher, classroom: @classroom, weekday: it) }
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_select "section#classroom_session_days" do
      assert_select "h2", text: I18n.t("#{scope}.session_days.title")
      assert_select "p", text: "Vos jours de séance : lundi, jeudi"
      # UDR-0077 §3.4 : « Modifier » est une entrée du menu ⋮ du bloc, plus un bouton visible.
      assert_select "button[aria-haspopup=menu][aria-controls=classroom-session-days-menu][aria-label=?]",
                    I18n.t("#{scope}.session_days.menu")
      assert_select "#classroom-session-days-menu[role=menu] a[role=menuitem][data-turbo-frame=modal]" \
                    "[href='#{edit_classroom_session_days_path(@classroom.public_id)}']", text: I18n.t("#{scope}.session_days.edit")
      assert_select "a.inline-flex[href='#{edit_classroom_session_days_path(@classroom.public_id)}']", 0
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

  test "ADR-0088 : la page d'une classe archivée n'existe plus, pour l'enseignant comme pour l'équipe : 404" do
    classroom = create_classroom(school: @school, status: "archived")
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom:)
    student = create_student(classroom:)
    sign_in_as @teacher

    get classroom_path(classroom.public_id)

    assert_response :not_found
    assert_no_match(/#{student.last_name}/, response.body)

    sign_in_as create_team_member
    get classroom_path(classroom.public_id)

    assert_response :not_found
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
    assert_badges assignment, [ "0 Bronze", "0 Argent", "0 Or", "1 Diamant" ]
    assert_badges on_time, [ "0 Bronze", "0 Argent", "0 Or", "0 Diamant" ]
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

  # ADR-0079 §4.1 : une remédiation sur l'exercice assigné, c'est faire cet exercice ; hors de l'assignation, elle ne compte pas.
  test "PRD : une remédiation sur l'assignation compte ; une autre classe, une remédiation hors de l'assignation, une session commencée, un élève parti ou anonymisé ne comptent pas" do
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
    remediated = create_student(classroom: @classroom)
    hand_in(assignment, 100, student: remediated, gap: create_gap(student: remediated, essential: exercise.essential))
    gone = hand_in(assignment, 100).student
    Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
    hand_in(assignment, 100).student.update_columns(anonymized_at: Time.current)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_badges assignment, [ "1 Bronze", "0 Argent", "0 Or", "1 Diamant" ]
    assert_select "#assignment_#{assignment.public_id} #{FOOTER} span.text-ink", text: "Pas encore lisible · 2/3"
    assert_select "#assignment_#{assignment.public_id} p", text: "2 faits · 1 pas encore fait"
  end

  test "une classe sans élève présent : badges à zéro et cercle gris « Pas encore lisible · 0/0 », sans erreur" do
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher)
    gone = hand_in(assignment, 100).student
    Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_response :success
    assert_badges assignment, [ "0 Bronze", "0 Argent", "0 Or", "0 Diamant" ]
    assert_select "#assignment_#{assignment.public_id} #{FOOTER}" do
      assert_select "span.bg-line.rounded-full", 1
      assert_select "span.text-ink", text: "Pas encore lisible · 0/0"
    end
    assert_select "#assignment_#{assignment.public_id} p", text: "0 fait · 0 pas encore fait"
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
    # UDR-0130 : une section de la page nomme l'objet, « Fiches de cours », et compte ses fiches de révision.
    assert_select "section#classroom_courses h2", text: "Fiches de cours"
    assert_select "section#classroom_courses li", 1
    assert_select "#classroom_course_#{genetics.slug}" do
      assert_select "a[href='#{classroom_course_path(classroom.public_id, genetics.slug)}']", text: "Génétique et évolution"
      assert_select "p", text: /#{I18n.t("#{scope}.courses.essentials", count: 1)}/
      assert_select "p", text: /1 fiche de révision/
    end
    assert_no_match(/Fonctions|Autre niveau/, response.body)
  end

  # CA-8 (UDR-0077 §3.4) : cours en bande, exercices assignés (3 puis « Voir plus »), élèves — dans cet ordre.
  test "CA-8 : l'ordre de la page — cours en bande, quatre exercices dont trois visibles, puis les élèves" do
    svt = create_material(name: "SVT", category: "science")
    level = create_level(name: "Tle")
    classroom = create_classroom(school: @school, level:)
    teacher = create_teacher(school: @school, material: svt, classrooms: [ classroom ])
    courses = [ "Génétique", "Écologie" ].map { create_course(level:, material: svt, name: it) }
    4.times { create_assignment(classroom:, assignable: create_exercise(essential: create_essential(course: courses.first)), by: teacher) }
    create_student(classroom:)
    sign_in_as teacher

    get classroom_path(classroom.public_id)

    assert_equal %w[classroom_courses assigned_exercises classroom_roster],
                 css_select("#classroom_courses, #assigned_exercises, #classroom_roster").map { it["id"] }
    assert_select "section#classroom_courses.min-w-0 [data-controller='communication--carousel']" do
      assert_select "ul.overflow-x-auto.snap-x[data-communication--carousel-target=track][aria-label=?] > li.basis-3\\/4",
                    I18n.t("#{scope}.courses.title"), count: 2
      assert_select "[data-communication--carousel-target=pager][aria-hidden=true] [data-communication--carousel-target=dot]", 2
    end
    assert_select "section#assigned_exercises[data-controller=reveal]" do
      assert_select "li[id^='assignment_'][data-reveal-target=item]", 4
      assert_select "li[id^='assignment_'][hidden]", 1
      assert_select "button[data-reveal-target=button]", text: /Voir plus/
    end
  end

  # EPM-18, EPM-19 (UDR-0127 §3.1, §3.3) : une bande par matière, titrée ; le collègue d'une autre matière ne voit que la
  # sienne, mais tous deux voient les exercices assignés de l'autre, avec leur badge.
  test "EPM-18 : l'enseignant de deux matières lit une bande par matière ; son collègue, la sienne et les exercices de l'autre" do
    pc = create_material(name: "Physique-Chimie", category: "science")
    svt = create_material(name: "SVT", category: "science")
    maths = create_material(name: "Mathématiques", category: "science")
    level = create_level(name: "3ème")
    classroom = create_classroom(school: @school, level:, name: "3ème 2")
    both = create_teacher(school: @school, materials: [ pc, svt ], classrooms: [ classroom ])
    colleague = create_teacher(school: @school, material: maths, classrooms: [ classroom ])
    optics = create_course(level:, material: pc, name: "Optique")
    cells = create_course(level:, material: svt, name: "La cellule")
    create_course(level:, material: maths, name: "Fonctions")
    create_assignment(classroom:, assignable: create_exercise(title: "Les tissus", essential: create_essential(course: cells)), by: both)
    sign_in_as both

    get classroom_path(classroom.public_id)

    assert_equal [ "classroom_courses_#{pc.slug}", "classroom_courses_#{svt.slug}" ],
                 css_select("#classroom_courses div[id^=classroom_courses_]").map { it["id"] }
    assert_select "#classroom_courses_#{pc.slug} h3", text: /Physique-Chimie/
    assert_select "#classroom_courses_#{pc.slug} ul[aria-label='Fiches de cours de Physique-Chimie'] #classroom_course_#{optics.slug}"
    assert_no_match(/Fonctions/, response.body)
    sign_out
    sign_in_as colleague

    get classroom_path(classroom.public_id)

    assert_select "#classroom_courses h3", 0
    assert_select "#classroom_courses li", 1
    assert_select "#assigned_exercises", text: /Les tissus/
    assert_select "#assigned_exercises", text: /SVT/
  end

  test "bloc « Cours » sans cours publié : l'état vide" do
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_select "#classroom_courses_empty", text: /#{I18n.t("#{scope}.courses.empty_title")}/
  end

  test "la direction de l'établissement reçoit 403, sans nom ni identifiant d'élève, ni badges ni cercle (UDR-0052)" do
    student = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher)
    5.times { hand_in(assignment, 90) }
    hand_in(assignment, 40, student:)
    sign_in_as create_school_admin(school: @school)

    get classroom_path(@classroom.public_id)

    assert_response :forbidden
    assert_no_match(/Bamba|#{student.public_id}|Badges de la classe|Pas encore lisible|Acquis · /, response.body)
    assert_select "h2", text: "Compréhension", count: 0
    assert_select "#assigned_exercises, #assignment_#{assignment.public_id}", 0
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
    assert_select "#classroom_header #classroom_link", 1
    assert_select "#student_#{student.public_id}", text: /Awa Bamba/
  end

  test "FU-48 : « Chercher un élève » ne garde que les élèves de la classe dont le nom correspond" do
    awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
    koffi = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")
    other = create_student(classroom: create_classroom(school: @school), first_name: "Awa", last_name: "Ailleurs")
    sign_in_as @teacher

    get classroom_path(@classroom.public_id, q: "awa")

    assert_response :success
    assert_select "#classroom_roster_title", text: /\A\s*#{I18n.t("#{scope}.roster.title", count: 2)}/
    assert_select "input[name=q][value=awa]"
    assert_select "#classroom_roster_list [aria-live=polite]", text: I18n.t("#{scope}.roster.count", count: 1)
    assert_select "#student_#{awa.public_id}", 1
    assert_select "#student_#{koffi.public_id}", 0
    assert_select "#student_#{other.public_id}", 0
  end

  # Chantier politique-cache, lot E6 (ADR-0067) : les icônes des lignes sont dessinées une fois, dans le frame
  # « classroom_roster_list » qu'une recherche remplace seul.
  test "the roster takes its icons from symbols drawn once, in its frame, on the page and in a search" do
    create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
    create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)
    assert_icons_drawn_once "turbo-frame#classroom_roster_list"

    get classroom_path(@classroom.public_id, q: "awa"), headers: { "Turbo-Frame" => "classroom_roster_list" }
    assert_icons_drawn_once "turbo-frame#classroom_roster_list"
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

  # CA-B7 (provisoire, MVP teacher-student) : le code de la classe, affiché K7M 4Q2 et copiable, dans le bloc du lien.
  test "CA-B7 : l'enseignant de la classe voit « Code de la classe » avec son code et un bouton « Copier »" do
    code = Entities::Classroom::JoinCode.display(@classroom.reload.join_code)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_response :success
    assert_match(/\A[A-HJKMNP-Z2-9]{3} [A-HJKMNP-Z2-9]{3}\z/, code)
    assert_select "#classroom_link #classroom_code" do
      assert_select "#classroom_code_label", text: I18n.t("#{scope}.link.code_label")
      assert_select "#classroom_code_value", text: code
      assert_select "[data-clipboard-text-value='#{code}'] button[aria-label='#{I18n.t("#{scope}.link.code_copy_label")}']",
                    text: I18n.t("#{scope}.link.code_copy")
    end
  end

  test "CA-B7 : un enseignant d'une autre classe n'a ni la page ni le code" do
    code = Entities::Classroom::JoinCode.display(@classroom.reload.join_code)
    sign_in_as create_teacher(school: @school)

    get classroom_path(@classroom.public_id)

    assert_response :forbidden
    assert_select "#classroom_code", 0
    assert_no_match code, response.body
  end

  test "CA-B7 : après « Changer le lien et le code », le code affiché est le nouveau" do
    old_code = Entities::Classroom::JoinCode.display(@classroom.reload.join_code)
    sign_in_as @teacher

    patch classroom_link_path(@classroom.public_id), as: :turbo_stream
    new_code = Entities::Classroom::JoinCode.display(@classroom.reload.join_code)

    assert_not_equal old_code, new_code
    assert_select "turbo-stream[action=replace][target=classroom_link] template" do
      assert_select "#classroom_code_value", text: new_code
      assert_select "[data-clipboard-text-value='#{new_code}']"
    end
    assert_no_match old_code, response.body

    get classroom_path(@classroom.public_id)

    assert_select "#classroom_code_value", text: new_code
    assert_no_match old_code, response.body
  end

  test "une classe vide, sans cours ni élève, le dit" do
    classroom = create_classroom(school: @school)
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom:)
    sign_in_as @teacher

    get classroom_path(classroom.public_id)

    assert_response :success
    assert_select "#classroom_link", 1
    assert_select "#assigned_courses_empty", 0
    assert_select "#classroom_roster_empty", text: /#{I18n.t("#{scope}.roster.empty_title")}/
    assert_select "#classroom-roster-search", 0
    assert_select "#classroom_roster_list", 0
  end

  # IL-13 (ADR-0085 §4.4, UDR-0081 §3.7) : « Nouveau » pendant 7 jours, la voie sous chaque nom, les nouveaux en tête,
  # le compte des nouveaux dans le titre de la liste.
  test "IL-13 : « Nouveau » et « Inscrit seul » sur l'arrivé d'il y a 2 jours, « Par le lien » seul sur celui d'il y a 10 jours" do
    awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba", joined_via: "link", joined_at: 10.days.ago)
    koffi = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao", joined_via: "standard", joined_at: 2.days.ago)
    ali = create_student(classroom: @classroom, first_name: "Ali", last_name: "Cissé", joined_via: "code", joined_at: 1.year.ago)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_select "h2#classroom_roster_title[tabindex='-1']", text: /#{I18n.t("#{scope}.roster.title", count: 3)}/ do
      assert_select "span", text: I18n.t("#{scope}.roster.new_count", count: 1)
    end
    assert_select "h2#classroom_roster_title[data-controller]", 0
    assert_equal [ koffi, awa, ali ].map { "student_#{it.public_id}" }, css_select("#classroom_roster_list li[id]").map { it["id"] }
    assert_select "#student_#{koffi.public_id}" do
      assert_select "span", text: I18n.t("#{scope}.roster.new")
      assert_select "p.text-xs.text-mute", text: I18n.t("#{scope}.roster.via.standard")
    end
    assert_select "#student_#{awa.public_id}" do
      assert_select "span", text: I18n.t("#{scope}.roster.new"), count: 0
      assert_select "p.text-xs.text-mute", text: I18n.t("#{scope}.roster.via.link")
    end
    assert_select "#student_#{ali.public_id}", text: /#{I18n.t("#{scope}.roster.via.standard")}|#{I18n.t("#{scope}.roster.via.link")}/,
                                                count: 0
    assert_select "#student_#{ali.public_id}", text: /#{I18n.t("#{scope}.roster.new")}/, count: 0
  end

  test "IL-13 : sans nouvel arrivé, le titre n'a pas de pastille" do
    create_student(classroom: @classroom, joined_at: 8.days.ago)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_select "h2#classroom_roster_title", text: I18n.t("#{scope}.roster.title", count: 1)
    assert_select "h2#classroom_roster_title span", 0
  end

  # rapports-de-classe (memo Q4, UDR-0108 §3.2) : « Retirer de la classe » a quitté la ligne pour la fiche de l'élève.
  test "Q4 : aucune ligne n'a de menu ⋮ ni de fenêtre de retrait, pour l'enseignant comme pour l'équipe" do
    koffi = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")

    [ @teacher, create_team_member ].each do |reader|
      sign_in_as reader
      get classroom_path(@classroom.public_id)

      assert_select "#student_#{koffi.public_id} a[href='#{classroom_student_path(@classroom.public_id, koffi.public_id)}']"
      assert_select "dialog#remove-student-#{koffi.public_id}, #student-actions-#{koffi.public_id}", 0
      sign_out
    end
  end

  # rapports-de-classe, Lot B (CL-15 ; ADR-0097 §4.7, UDR-0108 §3.3, §3.4) : trente élèves, puis « Voir les suivants ».
  def roster_of(count)
    Array.new(count) { |index| create_student(classroom: @classroom, first_name: format("N%02d", index), last_name: "Élève", joined_at: 1.month.ago) }
  end

  test "CL-15 : 31 élèves, la liste en montre 30, « 30 sur 31 », et « Voir le dernier » vise la page 2 dans le cadre" do
    students = roster_of(31)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_select "#classroom_roster_list li[id^=student_]", 30
    assert_select "#classroom_roster_count[aria-live=polite]", text: I18n.t("#{scope}.roster.count_partial", shown: 30, total: 31)
    assert_select "#classroom_roster_more a[href='#{classroom_path(@classroom.public_id, note: 'none', page: 2, anchor: 'classroom_roster')}']" \
                  "[data-turbo-frame=classroom_roster_list][data-turbo-action=replace]",
                  text: I18n.t("#{scope}.roster.more", count: 1)
    assert_select "#student_#{students.last.public_id}", 0

    get classroom_path(@classroom.public_id, page: 2)

    assert_select "#classroom_roster_list li[id^=student_]", 31
    assert_select "#classroom_roster_count", text: I18n.t("#{scope}.roster.count", count: 31)
    assert_select "#classroom_roster_more", 0
    # UDR-0108 §3.3 : le focus va au lien de la première ligne ajoutée.
    assert_select "#student_#{students.last.public_id} a[data-controller=autofocus][data-autofocus-target=field]", 1
    assert_select "#classroom_roster_list [data-controller=autofocus]", 1
  end

  test "CL-15 : « Voir les suivants » garde la recherche ; le formulaire de recherche ne transmet pas la page" do
    roster_of(31)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id, q: "élève")

    assert_select "#classroom_roster_more a[href='#{classroom_path(@classroom.public_id, q: 'élève', page: 2, anchor: 'classroom_roster')}']"
    assert_select "form#classroom-roster-search input[name=page]", 0
  end

  # Décision du porteur du 2026-10-16 (UDR-0108 amendée) : la liste par note sur 20, un groupe à la fois.
  test "CL-15 : le sélecteur des notes compte chaque groupe, ouvre le premier non vide, et chaque groupe est un lien" do
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher)
    good = hand_in(assignment, 60).student
    hand_in(assignment, 95)
    waiting = create_student(classroom: @classroom)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_select "nav#classroom_roster_groups[aria-label=?]", I18n.t("#{scope}.roster.groups_label") do
      { "0-10" => 0, "11-15" => 1, "16-20" => 1, "none" => 1 }.each do |key, count|
        assert_select "a#classroom_roster_group_#{key.tr('-', '_')}[href='#{classroom_path(@classroom.public_id, note: key, anchor: 'classroom_roster')}']" \
                      "[data-turbo-action=advance]", text: /#{I18n.t("#{scope}.roster.groups.#{key}")}\s+#{count}/
      end
      assert_select "a[aria-current=true]", 1
      assert_select "a#classroom_roster_group_11_15[aria-current=true]"
    end
    assert_select "#classroom_roster_list li[id^=student_]", 1
    assert_select "#grade_#{good.public_id}", text: /#{I18n.t("#{scope}.roster.grade", grade: 12)}/

    get classroom_path(@classroom.public_id, note: "none")

    assert_select "#classroom_roster_list li[id^=student_]", 1
    assert_select "#grade_#{waiting.public_id}", text: /—/

    get classroom_path(@classroom.public_id, note: "0-10")

    assert_select "#classroom_roster_count", text: I18n.t("#{scope}.roster.empty_group")
    assert_select "#classroom_roster_list li[id^=student_]", 0

    get classroom_path(@classroom.public_id, q: "Awa")

    assert_select "#classroom_roster_groups a[aria-current]", 0
  end

  test "CL-15 : une page nulle, négative ou qui n'est pas un nombre montre la première page" do
    roster_of(31)
    sign_in_as @teacher

    %w[-1 abc 0 2x 1.5].each do |page|
      get classroom_path(@classroom.public_id, page:)

      assert_response :success
      assert_select "#classroom_roster_list li[id^=student_]", 30, page
      assert_select "#classroom_roster_list [data-controller=autofocus]", 0
    end
  end

  test "CL-15 : une page géante ne déborde pas : la liste entière, sans erreur" do
    roster_of(31)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id, page: "99999999999999999999")

    assert_response :success
    assert_select "#classroom_roster_list li[id^=student_]", 31
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

  # CA-16 (accueil-eleve, ADR-0089 §4.2, UDR-0084 §3.7) : la colonne « Fait seul (7 j) » ; 0 s'écrit « — », en text-mute ;
  # au téléphone, la ligne sous le nom. Les comptes de l'exercice donné ne bougent pas.
  test "CA-16 : « Fait seul (7 j) » vaut 1 pour l'élève qui a fini un exercice non donné il y a 3 jours, « — » pour l'autre" do
    exercise = create_exercise
    assignment = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher)
    awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
    koffi = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")
    create_exercise_session(student: koffi, exercise:, status: "completed", classroom_assignment: assignment)
    create_exercise_session(student: awa, status: "completed", started_at: 3.days.ago, completed_at: 3.days.ago)
    sign_in_as @teacher

    # Koffi a une note, Awa pas encore (groupes de l'UDR-0108 amendée) : la recherche porte sur toute la classe.
    get classroom_path(@classroom.public_id, q: "a")

    assert_select "#classroom_roster div#self_practice_heading.hidden.sm\\:flex", text: /#{Regexp.escape(I18n.t("#{scope}.roster.self_practice"))}/
    assert_select "#self_practice_#{awa.public_id}.hidden.sm\\:block", text: /#{Regexp.escape(I18n.t("#{scope}.roster.self_practice"))}\s+1/
    assert_select "#self_practice_#{koffi.public_id} span.text-mute", text: "—"
    assert_select "#self_practice_line_#{awa.public_id}.sm\\:hidden", text: "Fait seul : 1 cette semaine"
    assert_select "#self_practice_line_#{koffi.public_id}", text: "Fait seul : 0 cette semaine"
    assert_select "#assignment_#{assignment.public_id} p", text: /\A\s*1 fait\b.*1 pas encore fait\s*\z/
  end

  # AS-17, UDR-0121 §3.1, ADR-0101 §4.4 : le bloc « Fiches à revoir » de la page de classe.
  def gaps_tl(key, **) = I18n.t("#{scope}.gaps.#{key}", **)

  def gap_on(essential, student)
    source_session = create_exercise_session(student:, exercise: create_exercise(essential:, questions: 1), status: "completed",
                                             score_percent: 30)
    create_gap(student:, essential:, source_session:)
  end

  def class_with_gaps
    maths = create_material(name: "Mathématiques")
    set_teacher_materials(@teacher, @classroom.school, [ maths ])
    course = create_course(level: @classroom.level, material: maths, name: "Géométrie")
    thales = create_essential(course:, name: "Théorème de Thalès")
    physics = create_essential(course: create_course(level: @classroom.level, name: "Optique"), name: "Lentilles")
    awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
    bintou = create_student(classroom: @classroom, first_name: "Bintou", last_name: "Diallo")
    [ awa, bintou ].each { gap_on(thales, it) }
    gap_on(physics, awa)
    [ course, thales ]
  end

  test "fiches à revoir : l'enseignant voit la fiche de sa matière et son nombre d'élèves, entre exercices et élèves" do
    course, thales = class_with_gaps
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "#classroom_gaps h2", text: gaps_tl("title")
    assert_select "#classroom_gaps ul[data-turbo-prefetch=false] li", 1
    assert_select "#classroom_gaps li a[href='#{classroom_essential_path(@classroom.public_id, course.slug, thales.slug)}']",
                  text: "Théorème de Thalès"
    assert_select "#classroom_gaps li", text: /#{gaps_tl("students", count: 2)}/
    assert_select "#classroom_gaps", text: /Lentilles/, count: 0
    assert_match(/id="assigned_exercises".*id="classroom_gaps".*id="classroom_roster"/m, response.body)
  end

  test "fiches à revoir : l'équipe voit toutes les matières" do
    class_with_gaps
    sign_in_as create_team_member

    get classroom_path(@classroom.public_id)

    assert_select "#classroom_gaps li", 2
    assert_select "#classroom_gaps li", text: /Lentilles.*#{gaps_tl("students", count: 1)}/m
  end

  test "fiches à revoir : trois lignes, puis « Voir plus » qui révèle la suite sans requête" do
    maths = create_material(name: "Mathématiques")
    set_teacher_materials(@teacher, @classroom.school, [ maths ])
    course = create_course(level: @classroom.level, material: maths)
    students = 4.times.map { create_student(classroom: @classroom) }
    { "Une" => 1, "Quatre" => 4, "Deux" => 2, "Trois" => 3 }.each do |name, count|
      essential = create_essential(course:, name:)
      students.first(count).each { gap_on(essential, it) }
    end
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_select "#classroom_gaps[data-controller=reveal]" do
      assert_equal %w[Quatre Trois Deux Une], css_select("#classroom_gaps li a").map { it.text.strip }
      assert_select "li:not([hidden])", 3
      assert_select "li[hidden]", 1
      assert_select "li[hidden]", text: /Une/
      assert_select "button[data-action='reveal#more']"
    end
  end

  test "fiches à revoir : aucun bloc sans fiche à revoir" do
    create_student(classroom: @classroom)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "#classroom_gaps", 0
  end
end

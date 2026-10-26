require "test_helper"

# CL-10, CL-04 (affichage), ID-15 (émission par l'enseignant) — UDR-0027. La page d'une classe, pour l'enseignant qui y
# enseigne et pour l'équipe : en-tête et code en majuscules, liste des élèves avec le bouton du code de récupération.
# ADR-0072, UDR-0027 (amendée le 2026-10-02) : « Cours assignés » est retiré, un cours ne s'assignant plus. Un élève reçoit 403 : il voit le code de sa classe sur ses propres pages, jamais la liste nominative.
# Lot E de fonctions-espace-eleve (UDR-0062 §3.4) : jours de séance de l'enseignant, exercices assignés et leurs trois
# comptes, bloc « Cours » qui rouvre le chemin vers les exercices (memo Q18).
# Finitions (UDR-0054, FU-02, FU-07, FU-08, FU-26, FU-48) : titre, retour selon le rôle, copie par le contrôleur unique,
# « Chercher un élève » dans le frame de la liste.
class Classroom::ClassroomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan", sigle: "LCA")
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

  test "l'enseignant de la classe voit l'en-tête (titre, sigle et année), le bloc du lien et ses élèves, sans code ni « Cours assignés »" do
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
    # CA-I1 (UDR enseignant §3.5) : « LCA · 2026-2027 » sous le titre, le sigle de l'établissement et non son nom.
    assert_select "#{within_header} h1 + p", text: "LCA · #{@classroom.school_year}"
    assert_select within_header, text: /Lycée Classique d'Abidjan/, count: 0
    assert_select "#{within_header} img[src*='lnclass-teacher']", 1
    # IL-02, UDR-0081 §3.6 : le bloc du lien a remplacé le code.
    assert_select "#{within_header} #classroom_link", 1
    assert_select "#{within_header} [id*=join_code], [data-controller~='classroom--join-code-copy']", 0
    # CA-I1 : « 20 élèves » sans plafond, ni ligne provisoire du code (CA-B7).
    assert_select "#{within_header} #classroom_code, #classroom_headcount, #{within_header} details", 0
    assert_select "#classroom_roster_title", text: /#{I18n.t("#{scope}.roster.title", count: 2)}/
    assert_no_match(%r{2 / 60|sur 60}, response.body)

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

  # CA-I1 (UDR enseignant §3.5) : « Vos jours de séance » n'est plus rendu ; routes et données sont gardées.
  test "CA-I1 : jours de séance renseignés ou non, la page n'a pas le bloc « Vos jours de séance »" do
    [ 4, 1 ].each { Orm::ClassroomSessionDay.create!(teacher: @teacher, classroom: @classroom, weekday: it) }
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "section#classroom_session_days", 0
    assert_no_match(/jours de séance|Renseigner/i, response.body)

    Orm::ClassroomSessionDay.where(classroom: @classroom).delete_all
    get classroom_path(@classroom.public_id)

    assert_select "section#classroom_session_days", 0
    assert_no_match(/jours de séance|Renseigner/i, response.body)
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

  def assert_progress(assignment, done, total)
    assert_select "#assignment_#{assignment.public_id} [role=progressbar][aria-valuenow='#{done}'][aria-valuemax='#{total}']", 1
    assert_select "#assignment_#{assignment.public_id} span", text: I18n.t("assessment.comprehension.progress.done", count: done, total:)
  end

  # CA-I1 (UDR enseignant §3.5, §3.3) : le format de « Cette semaine » : titre, matière et échéance, barre, « 18 / 25 faits »,
  # pastille « 7 en retard » (pas fait et échu) ou « pas encore ».
  test "CA-I1 : la ligne de l'exercice échu dit « 18 / 25 faits » avec « 7 en retard » et mène à son suivi" do
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
      assert_select "span", text: "7 en retard"
    end
    assert_progress assignment, 18, 25
    assert_no_match(/18 faits, dont|pas encore faits|Pas encore lisible|Badges de la classe/, response.body)
  end

  test "sans échéance échue, la ligne dit « pas encore » et jamais « en retard », et l'équipe la lit aussi" do
    exercise = create_exercise(title: "Les gamètes")
    assignment = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher)
    on_time = create_assignment(classroom: @classroom, assignable: create_exercise(title: "À l'heure"), by: @teacher,
                                due_on: Date.current + 3)
    student = create_student(classroom: @classroom)
    create_exercise_session(student:, exercise:, status: "completed", classroom_assignment: assignment)
    create_student(classroom: @classroom)
    sign_in_as create_team_member

    get classroom_path(@classroom.public_id)

    assert_select "#assignment_#{assignment.public_id} span", text: "Sans date limite"
    assert_progress assignment, 1, 2
    assert_progress on_time, 0, 2
    assert_select "#assignment_#{assignment.public_id} span", text: "1 pas encore"
    assert_select "#assignment_#{on_time.public_id} span", text: "2 pas encore"
    assert_no_match(/en retard/, response.body)
    assert_select "section#classroom_session_days", 0
  end

  def hand_in(assignment, score_percent, student: create_student(classroom: @classroom), **attributes)
    create_exercise_session(student:, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed",
                            score_percent:, classroom_assignment: assignment, **attributes)
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

    assert_progress assignment, 2, 3
  end

  test "une classe sans élève présent : « 0 / 0 faits », sans erreur" do
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher)
    gone = hand_in(assignment, 100).student
    Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_response :success
    assert_progress assignment, 0, 0
  end

  test "sans les comptes (hors FollowAssignmentPolicy), la ligne n'a ni barre, ni « faits », ni lien vers le suivi" do
    row = Queries::Classroom::ClassroomOverviewQuery::AssignmentRow.new(
      public_id: "a1", exercise_title: "La méiose", material_name: "SVT", material_category: "science", due_on: nil,
      counts: nil, comprehension: nil
    )

    html = ApplicationController.render(partial: "classroom/classrooms/assigned_exercises",
                                        locals: { classroom: @classroom, assignments: [ row ] })

    assert_includes html, "La méiose"
    assert_no_match(/progressbar|faits|en retard|classroom_assignment|\/assignments\//, html)
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

    assert_select "#assigned_exercises [role=progressbar]", 3
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

  # CA-I1, CA-B8 (partie classe) : la ligne provisoire du code (CA-B7) a disparu de la page ; le code est sur la carte de l'accueil.
  test "CA-I1 : la page de classe n'affiche ni le code de la classe ni son bouton « Copier »" do
    code = Entities::Classroom::JoinCode.display(@classroom.reload.join_code)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "#classroom_code, #classroom_code_value, #classroom_code_label", 0
    assert_no_match code, response.body
    assert_no_match(/Code de la classe/, response.body)
    assert_select "#classroom_link" do
      assert_select "#classroom_link_label", text: "Inscrire vos élèves"
      assert_select "p", text: "Ils s'inscrivent avec le lien, classe déjà choisie."
      assert_select "a#classroom_whatsapp_share", text: "Partager sur WhatsApp"
      assert_select "[data-clipboard-text-value='#{join_classroom_url(@classroom.reload.link_token)}'] button", text: "Copier le lien"
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

  test "CA-I1 : après « Changer le lien », le bloc rendu n'a toujours pas de code" do
    old_code = Entities::Classroom::JoinCode.display(@classroom.reload.join_code)
    sign_in_as @teacher

    patch classroom_link_path(@classroom.public_id), as: :turbo_stream

    assert_select "turbo-stream[action=replace][target=classroom_link] template" do
      assert_select "#classroom_code_value, #classroom_code", 0
    end
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
    assert_select "#classroom_roster_more a[href='#{classroom_path(@classroom.public_id, page: 2, anchor: 'classroom_roster')}']" \
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

  # CA-I2 (UDR enseignant §3.2, §3.5) : « Tous · Bronze · Argent · Or · Diamant · Pas encore », paramètre `badge=`.
  def roster_students(selector = "#classroom_roster_list li[id^=student_]") = css_select(selector).map { it["id"] }

  test "CA-I2 : la ligne d'un élève dit « 2 faits sur 3 », son retard et son badge « Or · 17/20 » ; sans exercice fait, « Pas encore »" do
    due = Date.new(2026, 10, 8)
    exercises = Array.new(3) do |index|
      travel_to(Time.zone.local(2026, 10, 5, 9)) do
        create_assignment(classroom: @classroom, assignable: create_exercise(title: "Ex #{index}"), by: @teacher, due_on: due)
      end
    end
    gold = create_student(classroom: @classroom, first_name: "Aya", last_name: "Kouadio")
    waiting = create_student(classroom: @classroom, first_name: "Yann", last_name: "Gbagbo")
    hand_in(exercises[0], 90, student: gold, completed_at: Time.zone.local(2026, 10, 7, 10))
    hand_in(exercises[1], 80, student: gold, completed_at: Time.zone.local(2026, 10, 9, 10))
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_select "#progress_#{gold.public_id}", text: "2 faits sur 3 · 1 en retard"
    assert_select "#progress_#{gold.public_id} .text-warning", text: /1 en retard/
    assert_select "#badge_#{gold.public_id}", text: "Or · 17/20"
    # Sans rien de fait, les trois exercices échus sont en retard.
    assert_select "#progress_#{waiting.public_id}", text: "0 fait sur 3 · 3 en retard"
    assert_select "#badge_#{waiting.public_id}.text-mute", text: "Pas encore"
    assert_select "#grade_#{gold.public_id}", 0
  end

  test "CA-I2 : un filtre par badge, un lien par puce ; « Tous » est la puce courante par défaut" do
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher)
    gold = hand_in(assignment, 95).student
    silver = hand_in(assignment, 75).student
    waiting = create_student(classroom: @classroom)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_select "nav#classroom_roster_badges[aria-label=?]", I18n.t("#{scope}.roster.badges_label") do
      assert_select "a", 6
      assert_equal [ "Tous", "Bronze", "Argent", "Or", "Diamant", "Pas encore" ], css_select("nav#classroom_roster_badges a").map { it.text.squish }
      assert_select "a#classroom_roster_badge_all[href='#{classroom_path(@classroom.public_id, anchor: 'classroom_roster')}'][aria-current=true]"
      %w[bronze silver gold diamond none].each do |key|
        assert_select "a#classroom_roster_badge_#{key}[href='#{classroom_path(@classroom.public_id, badge: key, anchor: 'classroom_roster')}']" \
                      "[data-turbo-action=advance]"
        assert_select "a#classroom_roster_badge_#{key}[aria-current]", 0
      end
      assert_select "a[aria-current=true]", 1
    end
    assert_equal [ gold, silver, waiting ].map { "student_#{it.public_id}" }.sort, roster_students.sort
  end

  test "CA-I2 : le filtre « Or » ne montre que les élèves Or ; « Pas encore », ceux sans badge ; un filtre vide le dit" do
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher)
    gold = hand_in(assignment, 95).student
    hand_in(assignment, 75)
    low = hand_in(assignment, 30).student
    waiting = create_student(classroom: @classroom)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id, badge: "gold")

    assert_equal [ "student_#{gold.public_id}" ], roster_students
    assert_select "a#classroom_roster_badge_gold[aria-current=true]"
    assert_select "a#classroom_roster_badge_all[aria-current]", 0
    assert_select "#classroom_roster_count", text: I18n.t("#{scope}.roster.count", count: 1)

    get classroom_path(@classroom.public_id, badge: "none")

    assert_equal [ low, waiting ].map { "student_#{it.public_id}" }.sort, roster_students.sort

    get classroom_path(@classroom.public_id, badge: "diamond")

    assert_empty roster_students
    assert_select "#classroom_roster_count", text: I18n.t("#{scope}.roster.empty_badge")

    get classroom_path(@classroom.public_id, badge: "platine")

    assert_equal 4, roster_students.size
    assert_select "a#classroom_roster_badge_all[aria-current=true]"
  end

  test "CA-I2 : la recherche se combine au filtre ; la page et la recherche gardent le badge" do
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher)
    awa = hand_in(assignment, 95, student: create_student(classroom: @classroom, first_name: "Awa")).student
    hand_in(assignment, 95, student: create_student(classroom: @classroom, first_name: "Koffi"))
    hand_in(assignment, 75, student: create_student(classroom: @classroom, first_name: "Awa", last_name: "Argent"))
    sign_in_as @teacher

    get classroom_path(@classroom.public_id, badge: "gold", q: "awa")

    assert_equal [ "student_#{awa.public_id}" ], roster_students
    assert_select "form#classroom-roster-search input[type=hidden][name=badge][value=gold]", 1
    assert_select "a#classroom_roster_badge_silver[href='#{classroom_path(@classroom.public_id, q: 'awa', badge: 'silver', anchor: 'classroom_roster')}']"

    get classroom_path(@classroom.public_id)

    assert_select "form#classroom-roster-search input[name=badge]", 0
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

    get classroom_path(@classroom.public_id, q: "a")

    assert_select "#classroom_roster div#self_practice_heading.hidden.sm\\:flex", text: /#{Regexp.escape(I18n.t("#{scope}.roster.self_practice"))}/
    assert_select "#self_practice_#{awa.public_id}.hidden.sm\\:block", text: /#{Regexp.escape(I18n.t("#{scope}.roster.self_practice"))}\s+1/
    assert_select "#self_practice_#{koffi.public_id} span.text-mute", text: "—"
    assert_select "#self_practice_line_#{awa.public_id}.sm\\:hidden", text: "Fait seul : 1 cette semaine"
    assert_select "#self_practice_line_#{koffi.public_id}", text: "Fait seul : 0 cette semaine"
    assert_progress assignment, 1, 2
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

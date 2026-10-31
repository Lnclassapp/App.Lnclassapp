require "test_helper"

# CL-22, CL-10 (volet élève) — UDR-0011. « Ma classe » : la classe principale de l'élève, le code de la classe en
# majuscules. Jamais la liste nominative : aucun nom de camarade dans la page. Amendement du 2026-10-02 (UDR-0057) : ni
# sous-titre ni aide permanente, aucune action principale. UDR-0076 §3.2 : sous la classe, les cours des exercices
# assignés en carrousel, les exercices assignés pas encore faits, puis les exercices traités au meilleur score.
class Classroom::StudentClassroomsControllerTest < ActionDispatch::IntegrationTest
  # SobrietyAssertions::PRIMARY_ACTION, read here by assert_select: the browser assertions are for system tests.
  PRIMARY_ACTION = SobrietyAssertions::PRIMARY_ACTION.split(", ").map { "#main #{it}" }.join(", ").freeze

  setup do
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée Classique"),
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
    # CA-1 (UDR-0086 §3.1): no « Accueil » back link above the title any more; the header and the menus lead home.
    assert_select "#main nav[aria-label=?]", I18n.t("components.back_link.label"), 0
    # CA-2 (UDR-0086 §3.2): the classroom card on the blue gradient, without the count or the list of its students.
    assert_select "section#student_classroom_header.bg-linear-to-br.from-brand-strong.to-brand.text-white" do
      assert_select "h2", text: "Tle D 1"
      assert_select "*", text: "Tle · D"
      assert_select "*", text: "Lycée Classique"
      assert_select "*", text: "2026-2027"
      # IL-02, UDR-0081 §3.8 : plus de code de classe, sans rien à la place.
      assert_select "[id*=join_code]", 0
    end
    assert_no_match(/Code de la classe/, response.body)
    assert_select "#student_classroom_header", text: /élève/, count: 0
    # Ni effectif nu : deux élèves dans la classe, aucun « 2 » isolé (l'année « 2026-2027 » n'en est pas un).
    assert_no_match(/(?<![\d-])2(?![\d-])/, css_select("#student_classroom_header").text)
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

  # CA-13, CA-16 (prepare-interros-cahier, Lot F) : un exercice assigné se lit sur une feuille, avec « Rendre à l'enseignant » ;
  # une session commencée n'y change rien, et ni note ni correction n'est écrite avant le rendu.
  test "CA-16: an assigned exercise is on a sheet with « Rendre à l'enseignant », without grade nor correction, even after a started session" do
    exercise = assign("En cours", course: course_named("Génétique"))
    create_exercise_session(student: @student, exercise:, status: "started")
    sign_in_as @student

    get student_classroom_path

    assert_select "#student_classroom_assigned .ps-sheet #sheet-exercise-#{exercise.public_id}" do
      assert_select "button", text: I18n.t("catalog.courses.sheets.hand_in")
      assert_select "input[name=assignment_public_id][value=?]", Orm::ClassroomAssignment.sole.public_id
      assert_select "button", text: I18n.t("catalog.courses.sheets.check"), count: 0
      assert_select ".ps-result", 0
    end
    assert_select ".ps-footer .ps-link-button", 0
    assert_no_match "Commencer", css_select("#student_classroom_assigned").text
  end

  def sections = css_select("#student_classroom [id^=student_classroom_]:not([id$=_title])").map { it["id"] }

  # UDR-0076 §3.2, UDR-0086 §3.4 : la classe, puis « Cours assignés », « Exercices assignés », « Exercices traités », les
  # deux listes dans une grille qui les met côte à côte dès 1 024 px.
  test "below the classroom: the assigned courses, the assigned exercises, then the treated exercises" do
    create_teacher(school: @classroom.school, classrooms: [ @classroom ])
    sign_in_as @student

    get student_classroom_path

    assert_equal %w[student_classroom_header student_classroom_courses student_classroom_assigned student_classroom_treated],
                 sections
    # CA-E11 (UDR écrans élève §3.6 bis) : dès 1 024 px, les assignés dans la colonne de gauche (2/3), les traités à droite (1/3).
    assert_select "#student_classroom .lg\\:grid-cols-3 > .lg\\:col-span-2 > #student_classroom_assigned"
    assert_select "#student_classroom .lg\\:grid-cols-3 > #student_classroom_treated"
    assert_select "#student_classroom .lg\\:grid-cols-2", 0
  end

  # CA-E3 (mvp-teacher-student, option A) : avec une fiche à revoir, la section vient juste après « Exercices assignés »,
  # dans la même colonne, une ligne par fiche vers la fiche de cours ; sans fiche à revoir, rien.
  test "CA-E3: « Fiches à revoir » sits right after the assigned exercises, one link per sheet to review" do
    create_teacher(school: @classroom.school, classrooms: [ @classroom ])
    course = course_named("Génétique")
    gap = create_gap(student: @student, essential: create_essential(course:, name: "La méiose"))
    sign_in_as @student

    get student_classroom_path

    assert_equal %w[student_classroom_header student_classroom_courses student_classroom_assigned student_classroom_gaps
                    student_classroom_treated], sections
    assert_select "#student_classroom_assigned + #student_classroom_gaps" do
      assert_select "h2, h3", text: tl("pending_gaps.title")
      assert_select "a[href=?]", course_path(course.slug, anchor: "notion-#{gap.essential.slug}"), text: including("La méiose")
    end
  end

  test "CA-E3: without a sheet to review, no « Fiches à revoir » section" do
    create_gap(student: @student, essential: create_essential(course: course_named("Génétique")), status: "remediated")
    sign_in_as @student

    get student_classroom_path

    assert_select "#student_classroom_gaps", 0
    assert_no_match(/#{Regexp.escape(tl("pending_gaps.title"))}/, response.body)
  end

  # CA-3 (UDR-0086 §3.3) : sans enseignant sur Lnclass, la carte titrée sous celle de la classe, et le partage WhatsApp de
  # l'accueil (ADR-0089 §4.3) : la classe, l'établissement, le lien d'inscription enseignant, dans un nouvel onglet.
  test "a classroom without a teacher on Lnclass: the « Aucun enseignant » card and « Inviter mon enseignant », its only action" do
    create_teacher(school: @classroom.school, classrooms: [ create_classroom(school: @classroom.school) ])
    sign_in_as @student

    get student_classroom_path

    assert_equal %w[student_classroom_header student_classroom_no_teacher student_classroom_courses student_classroom_assigned
                    student_classroom_treated], sections
    message = I18n.t("classroom.student_homes.invite_teacher.message", classroom: "Tle D 1", school: "Lycée Classique",
                                                                      link: new_teacher_registration_url)
    assert_select "section#student_classroom_no_teacher[aria-labelledby=student_classroom_no_teacher_title]" do
      assert_select "h2#student_classroom_no_teacher_title", text: tl("no_teacher.title")
      assert_select "p", text: tl("no_teacher.description")
      assert_select "a.ui-button-brand[href=?][target=_blank][rel=noopener][aria-label=?]",
                    "https://wa.me/?text=#{ERB::Util.url_encode(message)}",
                    I18n.t("classroom.student_homes.invite_teacher.action_label"),
                    text: I18n.t("classroom.student_homes.invite_teacher.action")
    end
    assert_select PRIMARY_ACTION, 1
  end

  # CA-4 (UDR-0086 §3.3, UDR-0057 R1) : avec un enseignant, ni carte ni action, même avec des exercices à faire, et jamais
  # la liste des enseignants.
  test "a classroom with a teacher: neither the card nor any action, and no list of the teachers" do
    create_teacher(school: @classroom.school, classrooms: [ @classroom ], first_name: "Moussa", last_name: "Diabaté")
    assign("Méiose", course: course_named("Génétique"))
    sign_in_as @student

    get student_classroom_path

    assert_select "#student_classroom_no_teacher", 0
    assert_no_match I18n.t("classroom.student_homes.invite_teacher.action"), response.body
    assert_no_match "Diabaté", response.body
    # Le lien WhatsApp du support (« Besoin d'aide ? », support_helper) reste dans la coque ; la page n'en a aucun.
    assert_select "#student_classroom a[href*='wa.me']", 0
    assert_select PRIMARY_ACTION, 0
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

  # CA-13, CA-14 : un envoi, une feuille ; 3 exercices ou plus « Prépare devoirs », 1 ou 2 « Prépare interros » ; la plus récente en haut.
  test "CA-13, CA-14: one sheet per send, the right form by count, the newest first; an exercise already done stays on its sheet" do
    genetics = course_named("Génétique")
    notion = create_essential(course: genetics, name: "La méiose", sheet: { "remember" => "Deux divisions." })
    send_batch = lambda do |count, at, batch|
      Array.new(count) { create_exercise(essential: notion) }.each do
        create_assignment(classroom: @classroom, assignable: it, assigned_at: at, batch_public_id: batch)
      end
    end
    three = send_batch.(3, 2.hours.ago, "BATCHTHREEXXXX")
    two = send_batch.(2, 1.hour.ago, "BATCHTWOXXXXXX")
    complete(three.first, 90, at: 1.minute.ago)
    sign_in_as @student

    get student_classroom_path

    sheets = css_select("#student_classroom_assigned .ps-sheet")
    assert_equal [ "PRÉPARE INTERROS", "PRÉPARE DEVOIRS" ], sheets.map { it.at_css(".ps-header-title").text }
    assert_select "#student_classroom_assigned .ps-sheet:first-child" do
      assert_select ".ps-title", text: "La méiose"
      assert_select ".ps-remember", text: including("Deux divisions.")
      assert_select ".ps-exercise", two.size
    end
    assert_select "#student_classroom_assigned .ps-sheet:last-child" do
      assert_select ".ps-remember", text: including("Notions mobilisées :")
      assert_select ".ps-exercise", three.size
    end
    assert_select "#student_classroom_assigned[data-controller=reveal]", 0
  end

  test "CA-14: two exercises of different notions: no « À retenir »" do
    genetics = course_named("Génétique")
    [ create_exercise(essential: create_essential(course: genetics, sheet: { "remember" => "A" })),
      create_exercise(essential: create_essential(course: genetics, sheet: { "remember" => "B" })) ].each do
      create_assignment(classroom: @classroom, assignable: it, batch_public_id: "BATCHMIXEDXXXX")
    end
    sign_in_as @student

    get student_classroom_path

    assert_select "#student_classroom_assigned .ps-header-title", text: "PRÉPARE INTERROS"
    assert_select ".ps-remember", 0
  end

  # Sécurité : seule la classe de l'élève est lue.
  test "a student never reads the sheets of another classroom" do
    other_classroom = create_classroom(level: @classroom.level, series: @classroom.series, name: "Tle D 2")
    create_assignment(classroom: other_classroom, assignable: create_exercise(essential: create_essential(course: course_named("Secret"))),
                      batch_public_id: "BATCHOTHERXXXX")
    sign_in_as @student

    get student_classroom_path

    assert_select "#student_classroom_assigned .ps-sheet", 0
    assert_no_match "Secret", response.body
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
      # UDR-0145 : la carte entière mène au résultat ; la note et « Voir ma copie » y sont écrits.
      assert_select "li:first-child a[href=?]", exercise_session_result_path(last.public_id), text: "Refait"
      assert_select "li:first-child", text: including("16/20")
      assert_select "li:first-child", text: including("Voir ma copie")
      assert_select "button[data-action='reveal#more']"
    end
    assert_no_match "Autre élève", response.body
  end

  # CA-6 (UDR-0086 §3.4) : la note en vert à partir de 14/20, en encre en dessous, jamais en rouge. Les devoirs reçus sont des feuilles
  # noir et blanc (prepare-interros-cahier) : plus d'orange d'échéance, « À rendre le … » s'écrit sous le titre.
  test "the grades green from 14/20, never red" do
    genetics = course_named("Génétique")
    complete(create_exercise(essential: create_essential(course: genetics), title: "Réussi"), 75, at: 2.hours.ago)
    complete(create_exercise(essential: create_essential(course: genetics), title: "À revoir"), 45, at: 1.hour.ago)
    # UDR-0090 §4 : la règle de l'historique, sur la note affichée (grade_on_20 >= 14) : 68 % s'affiche 14/20, en vert.
    complete(create_exercise(essential: create_essential(course: genetics), title: "Juste"), 68, at: 3.hours.ago)
    # Le seuil bas : 66 % s'affiche 13/20, à l'encre.
    complete(create_exercise(essential: create_essential(course: genetics), title: "Presque"), 66, at: 4.hours.ago)
    sign_in_as @student

    get student_classroom_path

    assert_select "#student_classroom_treated" do
      assert_select "li .text-success", text: "15/20"
      assert_select "li .text-success", text: "14/20"
      assert_select "li .text-ink", text: "9/20"
      assert_select "li .text-success", text: "9/20", count: 0
      assert_select "li .text-ink", text: "13/20"
      assert_select "li .text-success", text: "13/20", count: 0
    end
    assert_select "#student_classroom_treated [class*=red], #student_classroom_treated [class*=error], #student_classroom_treated [class*=danger]", 0
  end

  # L'échéance d'un devoir reçu : « À rendre le … » sous le titre de sa feuille.
  test "the due date of a received sheet is written under its title" do
    exercise = assign("Pour demain", course: course_named("Génétique"), at: 1.day.ago)
    Orm::ClassroomAssignment.find_by!(assignable_id: exercise.id).update!(due_on: Date.current + 2)
    sign_in_as @student

    get student_classroom_path

    due = I18n.t("classroom.student_classrooms.assigned_sheet.due_on", date: I18n.l(Date.current + 2, format: :due_long))
    assert_select "#student_classroom_assigned .ps-title-block", text: including(due)
  end

  test "nothing assigned, nothing treated: the empty state of each section" do
    sign_in_as @student

    get student_classroom_path

    assert_select "#student_classroom_courses", text: including(tl("show.courses_empty"))
    assert_select "#student_classroom_assigned", text: including(tl("show.assigned_empty"))
    assert_select "#student_classroom_treated", text: including(tl("show.treated_empty"))
    assert_select "#main [data-controller=reveal]", 0
  end

  # ADR-0076 §4.1 (CA-8) : la page est personnelle, jamais dans un cache partagé ; ADR-0067 : un nombre fixe de requêtes.
  test "ADR-0076 — Ma classe is never public in a cache, and costs one round trip without a lazy frame" do
    sign_in_as @student

    get student_classroom_path

    assert_match(/private|no-store/, response.headers["Cache-Control"])
    assert_no_match(/public/, response.headers["Cache-Control"])
    assert_select "turbo-frame[src]", 0
  end

  def count_queries(&)
    count = 0
    counter = ->(*args) { count += 1 unless args.last[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end

  # PRD §7 : has_teacher se lit dans la requête de l'en-tête ; avec ou sans enseignant, le même nombre de requêtes.
  test "ADR-0067 — the same number of queries with and without a teacher" do
    assign("Méiose", course: course_named("Génétique"))
    sign_in_as @student
    without = count_queries { get student_classroom_path }
    assert_select "#student_classroom_no_teacher"

    create_teacher(school: @classroom.school, classrooms: [ @classroom ])
    with = count_queries { get student_classroom_path }

    assert_select "#student_classroom_no_teacher", 0
    assert_equal without, with
  end

  test "a classroom without series: the level alone" do
    classroom = create_classroom(level: create_level(name: "6ème"))
    sign_in_as create_student(classroom:)

    get student_classroom_path

    assert_select "#student_classroom_header", text: including("6ème")
    assert_select "#student_classroom_header", text: including(" · "), count: 0
  end

  test "CL-10: the student receives 403 on the teacher page of their own classroom" do
    sign_in_as @student

    get classroom_path(@classroom.public_id)

    assert_response :forbidden
    assert_no_match "KFM37", response.body
  end

  test "IL-14: a student without an active classroom: one redirection, to the home that offers to choose one" do
    sign_in_as create_student

    get student_classroom_path

    assert_redirected_to student_home_path
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

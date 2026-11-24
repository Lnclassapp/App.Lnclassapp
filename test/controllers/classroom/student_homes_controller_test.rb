require "test_helper"

# CL-23, TR-04, AS-36, TR-02 (UDR-0010, UDR accueil élève): the student home. The old feed raised NameError as soon as the student had a
# classroom, and a student without a classroom bounced between / and /students forever. Mvp-teacher-student, Lot D: the band, the
# next-step card and its six states, the grid of seven, the announcements, the history.
class Classroom::StudentHomesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée Classique"),
                                  level: create_level(name: "Tle"))
    @student = create_student(classroom: @classroom, first_name: "Aya", last_name: "Kouassi")
    # UDR-0013, amendement du 2026-10-01 : la classe de l'élève est du niveau du cours.
    @course = create_course(name: "Génétique", material: create_material(name: "SVT", category: "science"), level: @classroom.level)
    @essential = create_essential(course: @course, name: "La méiose")
  end

  # ComponentsHelper::BUTTON_VARIANTS, as CSS classes.
  PRIMARY = "ui-button-primary".freeze
  SECONDARY = "ui-button-secondary".freeze

  def tl(key, **) = I18n.t("classroom.student_homes.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/

  # ADR-0072 §4.1: each exercise is assigned on its own; assigned at the same instant, they follow their order in the sheet.
  def assign_together(*exercises, at: 1.hour.ago)
    exercises.each { create_assignment(classroom: @classroom, assignable: it, assigned_at: at) }
  end


  CARD = "section#student_class_card".freeze

  def assign_exercise(title, due_on: nil, assigned_at: 3.days.ago, **)
    exercise = create_exercise(essential: @essential, title:)
    create_assignment(classroom: @classroom, assignable: exercise, assigned_at:, due_on:, **)
    exercise
  end

  # One answer given (the copy is treated, it has a medal); blank: a copy without any answer, which has none.
  def complete(exercise, score: 80, blank: false)
    create_exercise_session(student: @student, exercise:, status: "completed", score_percent: score)
      .tap { create_attempt(session: it) unless blank }
  end

  def card_buttons = css_select("#{CARD} .ui-button-primary, #{CARD} .ui-button-secondary")

  # Amendement eleve-sans-prof (porteur, 2026-11-12) : « À faire » revient entre les annonces et l'historique.
  test "CA-D1: the band, the class card, the grid, the announcements, « À faire », the history frame, the invitation in this order; no bottom bar, no « Paiement »" do
    assign_exercise("Méiose, les étapes", due_on: Date.current + 2)
    create_message(author: create_team_member(second_factor: false), title: "Rentrée", published_at: 1.hour.ago, audience: "all")
    # Activation-eleve : un élève activé (une copie réussie) n'a plus la carte de son premier exercice.
    complete(create_exercise(essential: @essential), score: 80)
    sign_in_as @student

    get student_home_path

    assert_response :success
    assert_select "h1.sr-only", text: tl("show.page_title")
    ids = css_select("#student_home [id]").map { it["id"] }
    assert_equal %w[student_class_card student_subjects student_home_announcements student_to_do student_home_recent_activity student_invite_banner],
                 ids & %w[student_class_card student_subjects student_home_announcements student_to_do student_home_recent_activity student_invite_banner]
    assert_equal ids & %w[student_class_card student_subjects student_home_announcements student_to_do student_home_recent_activity student_invite_banner],
                 %w[student_class_card student_subjects student_home_announcements student_to_do student_home_recent_activity student_invite_banner]
    # The band is the shell's, above the column: 187 px, the help as an icon alone; the white starts 28 px above its bottom.
    assert_select "main > div.lg\\:hidden > header.student-band.bg-brand.text-on-brand.min-h-wave-band"
    assert_select "header.student-band a[href=?][aria-label=?]", help_path, "Besoin d'aide ?"
    assert_equal "", css_select("header.student-band a[href='#{help_path}']").text.strip
    assert_select "#student_home > div.-mt-wave-lap.rounded-t-wave.bg-white"
    assert_select "header.sticky.max-lg\\:hidden"
    assert_select "[class*='fixed bottom-0'], nav.fixed", 0
    assert_no_match(/À faire ensuite|Paiement|Exercice du jour|Prochain exercice/, response.body)
    assert_no_match "Bonjour", css_select("#main").text
  end

  test "the invitation banner is the only « Inviter »: WhatsApp in a new tab, a cross that hides it on this device" do
    sign_in_as @student

    get student_home_path

    assert_select "section#student_invite_banner[data-controller=dismissible][data-dismissible-key-value=student-invite-teacher]" do
      assert_select "h2", text: tl("invite_teacher.prompt")
      assert_select "a[target=_blank][rel~=noopener][href^='https://wa.me/?text=']", text: tl("invite_teacher.banner_action")
      assert_select "button[data-action='dismissible#hide'][aria-label=?]", tl("invite_teacher.banner_dismiss")
    end
    assert_select "#student_home a[href^='https://wa.me/']", 1
  end

  test "the page of another role keeps its header on every size: only the pages with a band hide it under lg" do
    sign_in_as @student

    get courses_path

    assert_select "header.sticky"
    assert_select "header.sticky.max-lg\\:hidden", 0
  end

  # CA-D10 (Lot O1): the wide page is the same markup with lg rules; nothing changes under lg.
  test "CA-D10: on a computer the column is 720 px at most, « Mes matières » is titled and has eight columns, the announcements show two cards" do
    create_message(author: create_team_member(second_factor: false), title: "Rentrée", published_at: 1.hour.ago, audience: "all")
    sign_in_as @student

    get student_home_path

    assert_select "#student_home.lg\\:max-w-180.lg\\:mx-auto.lg\\:w-full"
    assert_select "nav#student_subjects" do
      assert_select "h2", text: tl("subjects.label")
      assert_select "ul.grid-cols-4.lg\\:grid-cols-8"
    end
    assert_select "section#student_home_announcements.bg-mist.lg\\:bg-transparent"
    # The mist background and the sidebar are the shell's, for every student page; carte-profil-eleve (UDR-0132 §3.1, amended):
    # the profile card opens the sidebar, as the teacher's.
    assert_select "body > div.fixed.hidden.lg\\:block.bg-mist[aria-hidden=true]"
    assert_select "aside > div.rounded-card p.font-medium", 1
    assert_select "aside > nav[aria-label] a", 3
  end

  test "CA-D10: the other roles keep their page and their sidebar: no mist backdrop, the profile card stays" do
    teacher = create_teacher(school: @classroom.school, material: @course.material, classrooms: [ @classroom ])
    sign_in_as teacher

    get teacher_home_path

    assert_select "div.bg-mist.fixed", 0
    assert_select "aside > div.rounded-card p.font-medium"
  end


  test "CA-D1, CA-K3: the grid has no seventh « Inviter » tile; no « Paiement » ; no « abonnement » once subscribed (cartes-activation: the notice is for the free period)" do
    %w[Mathématiques Physique-Chimie Français Histoire-Géographie Philosophie EDHC].each do |name|
      create_course(material: create_material(name:, category: "literature"), level: @classroom.level)
    end
    subscribe_student(@student)
    sign_in_as @student

    get student_home_path

    assert_select "nav#student_subjects li", 7
    assert_select "#subject_invite", 0
    assert_no_match(/paiement|abonnement/i, css_select("#main").text)
  end

  test "the class card: « Entrer en classe » opens Ma classe; the QR of the school replaces its sigle" do
    @classroom.school.update!(sigle: "CM1T")
    sign_in_as @student

    get student_home_path

    assert_select "section#student_class_card" do
      assert_select "p", text: tl("class_card.label")
      assert_select "h2#student_class_title", text: "Tle D 1"
      assert_select "p", text: "Lycée Classique"
      assert_select "div#student_school_qr[role=img] svg"
      assert_select "#student_school_sigle", false
      assert_select "a#student_class_enter[href=?]", student_classroom_path, text: tl("class_card.enter")
      assert_select "img[alt='']"
    end
  end

  test "CA-D7: no classroom: « Choisis ta classe », the code field, « Rejoindre », « Je n'ai pas de code »; grid, announcements, history hidden" do
    sign_in_as create_student(classroom: create_classroom(status: "archived"))

    get student_home_path

    assert_response :success
    assert_select "section#student_choose_class" do
      assert_select "#student_choose_class_title", text: tl("no_classroom.title")
      assert_select "form#student-home-code-form[action=?][method=post]", student_classroom_choices_path do
        assert_select "input[name='student_classroom_choice[join_code]'][maxlength='6'][required]"
        assert_select "button[type=submit]", text: tl("no_classroom.submit")
      end
      assert_select "a#student_choose_class_no_code[href=?]", new_student_classroom_choice_path, text: tl("no_classroom.no_code")
      assert_select "a[href=?]", student_classroom_path, 0
    end
    # Sa classe archivée est d'un niveau sans cours publié : rien sous la carte (eleve-sans-prof CA-3).
    assert_select "#student_subjects, #student_history, #student_home_announcements, turbo-frame#student_home_recent_activity, #student_invite_banner", 0
    assert_select "header.sticky.max-lg\\:hidden"
  end

  test "CA-D7: the archive is offered beside the code to a student who has one, to no one else" do
    sign_in_as create_student(classroom: create_classroom(status: "archived"))
    get student_home_path
    assert_select "#student_choose_class a[href=?]", student_archive_path, text: tl("no_classroom.archive")

    sign_out
    sign_in_as create_student
    get student_home_path
    assert_select "#student_choose_class"
    assert_select "#student_choose_class a[href=?]", student_archive_path, 0
  end

  test "CA-D8: the subject of a late exercise carries the amber dot and the words, the others none" do
    create_course(material: create_material(name: "Mathématiques"), level: @classroom.level)
    assign_exercise("Méiose, en retard", due_on: Date.current - 2, assigned_at: 4.days.ago)
    sign_in_as @student

    get student_home_path

    assert_select "a#subject_svt span.bg-warning-dot[aria-hidden=true]", 1
    assert_select "a#subject_svt .sr-only", text: tl("subjects.late")
    assert_select "a#subject_mathematiques span.bg-warning-dot", 0
    assert_select "a#subject_mathematiques .sr-only", text: "Mathématiques"
  end

  test "a late exercise already done brings no dot" do
    done = assign_exercise("Fait en retard", due_on: Date.current - 2, assigned_at: 4.days.ago)
    complete(done)
    sign_in_as @student

    get student_home_path

    assert_select "a#subject_svt span.bg-warning-dot", 0
  end

  test "the grid: Philosophie is shown « Philo », its full name left to screen readers" do
    create_course(material: create_material(name: "Philosophie", category: "literature"), level: @classroom.level)
    sign_in_as @student

    get student_home_path

    assert_select "a#subject_philosophie span[aria-hidden=true]", text: "Philo"
    assert_select "a#subject_philosophie .sr-only", text: "Philosophie"
  end

  test "the grid: a round per subject of the student's level, in the charter order, the short names (full name for screen readers), no « Inviter »" do
    create_course(material: create_material(name: "Physique-Chimie"), level: @classroom.level)
    create_course(material: create_material(name: "Histoire-Géographie", category: "literature"), level: @classroom.level)
    maths = create_material(name: "Mathématiques")
    create_course(material: maths, level: @classroom.level)
    create_course(material: create_material(name: "Français", category: "literature"), level: create_level)
    create_course(material: create_material(name: "Philosophie", category: "literature"), level: @classroom.level, status: "draft")
    sign_in_as @student

    get student_home_path

    ids = css_select("#student_subjects li a").map { it["id"] }
    assert_equal %w[subject_histoire-geographie subject_mathematiques subject_physique-chimie subject_svt], ids.sort
    assert_select "nav#student_subjects[aria-labelledby=student_subjects_title]" do
      assert_select "h2#student_subjects_title", text: tl("subjects.label")
      assert_select "ul.grid-cols-4"
      assert_select "a#subject_physique-chimie[href=?]", courses_path(material: "physique-chimie"), text: "PC Physique-Chimie"
      assert_select "a#subject_physique-chimie span[aria-hidden=true]", text: "PC"
      assert_select "a#subject_physique-chimie .sr-only", text: "Physique-Chimie"
      assert_select "a#subject_histoire-geographie span[aria-hidden=true]", text: "HG"
      assert_select "a#subject_mathematiques span[aria-hidden=true]", text: "Maths"
      assert_select "a#subject_svt", text: "SVT"
      assert_select "a#subject_svt .bg-tint-green.size-14 img[src*='subjects/svt']"
    end
    assert_no_match(/subject_francais|subject_philosophie|Paiement/, response.body)
  end

  test "no published course at the student's level: no round, only the empty sentence, no « Inviter » tile" do
    sign_in_as create_student(classroom: create_classroom(level: create_level))

    get student_home_path

    assert_select "nav#student_subjects li", 0
    assert_select "nav#student_subjects a#subject_invite", 0
    assert_select "nav#student_subjects", text: including(tl("subjects.empty"))
  end

  test "the sheets to review are no longer listed on the home (Ma classe carries them)" do
    complete(assign_exercise("Fait", due_on: Date.current + 1))
    create_gap(student: @student, essential: @essential)
    sign_in_as @student

    get student_home_path

    assert_select "#student_home_gaps, #student_home_exercises, #student_home_daily, #student_next_step", 0
    assert_select "#student_home a[href*='#notion-']", 0
  end

  test "the history is a lazy frame without a title of its own; its frame alone lists the last sessions by day, a note and the way to Mon historique" do
    exercise = create_exercise(essential: @essential, title: "Méiose")
    session = complete(exercise, score: 90)
    sign_in_as @student

    get student_home_path

    assert_select "turbo-frame#student_home_recent_activity[loading=lazy][src='#{student_home_path}']"
    assert_select "section#student_history", 0

    get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }

    assert_response :success
    assert_select "turbo-frame#student_home_recent_activity[target=_top]" do
      assert_select "section#student_history h2", text: tl("history.title")
      assert_select "h3", text: tl("history.today")
      assert_select "a[href='#{exercise_session_result_path(session.public_id)}']", text: including("Méiose")
      assert_select "a[href='#{exercise_session_result_path(session.public_id)}'] img[src*='subjects/svt'][alt='']", 1
      assert_select "[data-medal]", text: including("Or")
      assert_select "*", text: %r{\d+\s*/\s*20|%}, count: 0
      assert_select "a#student_history_more", 0
    end
  end

  test "the history shows 3 lines by day, then « Voir plus » to Mon historique; yesterday has its own title" do
    travel_to Time.zone.now.change(hour: 12) # les heures de copie ne passent pas minuit, quelle que soit l'heure du test
    exercise = create_exercise(essential: @essential, title: "Méiose")
    3.times { |index| create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 90, completed_at: (index + 1).hours.ago) }
    create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 90, completed_at: 1.day.ago - 1.hour)
    sign_in_as @student

    get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }

    assert_select "turbo-frame#student_home_recent_activity" do
      assert_select "li", 3
      assert_select "h3", text: tl("history.today")
      assert_select "h3", text: tl("history.yesterday"), count: 0
      assert_select "a#student_history_more[href=?]", student_archive_path, text: "Voir plus (1)"
    end
  end

  # Activation-eleve, CA-12 : « Refaire » sur toute copie terminée, plus seulement sous l'Argent (hors pause, ADR-0115).
  test "the history shows a medal per line, never a grade or red; « Refaire » starts the exercise again, whatever the medal" do
    exercise = create_exercise(essential: @essential, title: "Méiose")
    # Les trois dernières copies ne tiennent pas dans 30 minutes : pas de pause, le bouton reste.
    [ 70, 65, 20, 68 ].zip([ 1, 2, 40, 50 ]).each { |score, minutes| complete(exercise, score:).update!(completed_at: minutes.minutes.ago) }
    sign_in_as @student

    get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }

    medals = css_select("turbo-frame#student_home_recent_activity li [data-medal]")
    assert_equal [ "Argent Médaille Argent", "Bronze Médaille Bronze", "Bronze Médaille Bronze" ], medals.map { it.text.squish }
    assert_select "turbo-frame#student_home_recent_activity", text: %r{\d+\s*/\s*20|%}, count: 0
    assert_select "turbo-frame#student_home_recent_activity [class*=error], turbo-frame#student_home_recent_activity [class*=bg-warning]", 0
    assert_select "turbo-frame#student_home_recent_activity form[action=?] button.ui-button-secondary", exercise_sessions_path(exercise.public_id),
                  text: tl("history.redo"), count: 3
  end

  # ADR médailles lues à la clôture : une copie vide n'a pas de médaille ; l'historique le dit, « Pas encore », comme le résultat.
  test "the history: a blank copy shows « Pas encore », never Bronze" do
    complete(create_exercise(essential: @essential, title: "Méiose"), score: 0, blank: true)
    sign_in_as @student

    get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }

    assert_equal [ "Pas encore" ], css_select("turbo-frame#student_home_recent_activity li [data-medal]").map { it.text.squish }
  end

  test "pause: 3 copies rendered within 30 minutes hide « Refaire » for that exercise only, and it returns once the pause is over" do
    paused = create_exercise(essential: @essential, title: "Pause test")
    other = create_exercise(essential: @essential, title: "Hors pause")
    [ 3, 2, 1 ].each { |minutes| complete(paused, score: 20).update!(completed_at: minutes.minutes.ago) }
    complete(other, score: 20).update!(completed_at: 30.seconds.ago)
    sign_in_as @student

    get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }

    assert_select "turbo-frame#student_home_recent_activity form[action=?]", exercise_sessions_path(paused.public_id), 0
    assert_select "turbo-frame#student_home_recent_activity form[action=?] button", exercise_sessions_path(other.public_id), text: tl("history.redo"), count: 1
    assert_select "turbo-frame#student_home_recent_activity a[href=?]", exercise_session_result_path(Orm::ExerciseSession.where(exercise_id: paused.id).order(completed_at: :desc).first.public_id), minimum: 1

    travel_to 31.minutes.from_now do
      get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }

      assert_select "turbo-frame#student_home_recent_activity form[action=?]", exercise_sessions_path(paused.public_id), minimum: 1
    end
  end

  test "pause: the history reads the recent copies of every exercise in one query" do
    exercises = Array.new(3) { |i| create_exercise(essential: @essential, title: "Ex #{i}") }
    exercises.each { |exercise| complete(exercise, score: 20).update!(completed_at: 1.minute.ago) }
    sign_in_as @student
    sql = []
    counter = ->(*, payload) { sql << payload[:sql] if payload[:sql].match?(/"exercise_sessions"/) && payload[:sql].match?(/ROW_NUMBER|completed_at/) && payload[:name] != "SCHEMA" }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }
    end

    assert_equal 1, sql.count { it.include?("ROW_NUMBER") }
  end

  test "no completed session: the history frame renders nothing, no title, no sentence, no « Voir plus »" do
    sign_in_as @student

    get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }

    assert_select "turbo-frame#student_home_recent_activity", 1
    assert_select "turbo-frame#student_home_recent_activity h2, turbo-frame#student_home_recent_activity a, turbo-frame#student_home_recent_activity button", 0
    assert_equal "", css_select("turbo-frame#student_home_recent_activity").text.strip
  end

  test "the class card has a title, and its section is named by it" do
    sign_in_as @student

    get student_home_path

    assert_select "section#student_class_card[aria-labelledby=student_class_title]"
    assert_select "#student_class_title", text: "Tle D 1"
  end

  test "the home reads classroom, then the page: nothing of the classmates and no code of the classroom" do
    create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yapo")
    sign_in_as @student

    get student_home_path

    assert_response :success
    assert_no_match "Yapo", response.body
    assert_no_match "Koffi", response.body
    assert_no_match(/Code de la classe/, response.body)
  end

  # ADR-0076 §4.1 (CA-8): the home is personal; the browser keeps it private, no shared cache ever does.
  test "ADR-0076 — the home is never public in a cache" do
    sign_in_as @student

    get student_home_path

    assert_match(/private|no-store/, response.headers["Cache-Control"])
    assert_no_match(/public/, response.headers["Cache-Control"])
  end

  # IL-14, IL-17 (UDR-0081 §3.5): the home of a student without an active classroom (archived, or removed) answers, and
  # offers « Choisis ta classe » in place of the classroom card. A removal under 7 days old says why, once.
  REMOVED = "Tu ne fais plus partie de cette classe. Choisis ta classe.".freeze

  def remove(student, classroom, at:)
    Orm::ClassroomStudent.where(student:, classroom:).update_all(left_at: at, removed_at: at, removed_by_id: create_teacher.id)
  end

  def assert_choose_your_classroom
    assert_response :success
    assert_select "h1.sr-only", text: tl("show.page_title")
    assert_select "#student_choose_class", text: including(tl("no_classroom.title")) do
      assert_select "a[href='#{new_student_classroom_choice_path}']", text: tl("no_classroom.no_code")
    end
    assert_equal [ "Choisis ta classe", "Je n'ai pas de code" ], [ tl("no_classroom.title"), tl("no_classroom.no_code") ]
    assert_select "#student_history, turbo-frame#student_home_recent_activity", 0
  end

  # Chantier eleve-sans-prof, PRD CA-1 à CA-3 : sans classe active, les matières et l'exercice du jour de son dernier niveau.
  test "eleve-sans-prof CA-1: removed from a class, the grid of its last level and « Choisis ta classe », no exercise of the day" do
    create_exercise(essential: @essential, title: "La méiose en bref")
    remove(@student, @classroom, at: 10.days.ago)
    sign_in_as @student

    get student_home_path

    assert_choose_your_classroom
    assert_select "nav#student_subjects a#subject_svt[href=?]", courses_path(material: "svt"), text: "SVT"
    assert_select "#subject_invite, #student_next_step_daily_block", 0
    assert_select "#student_choose_class button.ui-button-primary[type=submit]", text: tl("no_classroom.submit")
    assert_no_match "La méiose en bref", response.body
  end

  test "eleve-sans-prof CA-2: the subject of the last level opens; another level stays closed" do
    daily = create_exercise(essential: @essential, title: "La méiose en bref")
    other = create_course(name: "Fractions", material: create_material(name: "Mathématiques"), level: create_level(name: "6e"))
    remove(@student, @classroom, at: 10.days.ago)
    sign_in_as @student

    get courses_path(material: "svt")
    assert_select "a[href=?]", course_path(@course.slug)
    get course_path(@course.slug)
    assert_response :success
    get course_path(other.slug)
    assert_response :not_found
    post exercise_sessions_path(daily.public_id)
    assert_response :redirect
    assert_equal 1, Orm::ExerciseSession.where(student: @student).count
  end

  test "À faire: the open assigned exercises by due date, 3 shown then « Voir plus (n) », the due text on the right; the finished one is not listed" do
    now = 1.hour.ago
    exercises = [ [ "Un", 1 ], [ "Deux", 2 ], [ "Trois", 3 ], [ "Quatre", 4 ], [ "Cinq", 5 ] ].map do |title, days|
      assign_exercise(title, due_on: Date.current + days, assigned_at: now)
    end
    complete(assign_exercise("Fait", due_on: Date.current + 1, assigned_at: now))
    sign_in_as @student

    get student_home_path

    assert_select "section#student_to_do h2", text: tl("to_do.title")
    assert_equal %w[Un Deux Trois Quatre Cinq], css_select("#student_to_do li a span.text-brand-strong.font-semibold.leading-snug").map { it.text.strip }
    assert_select "#student_to_do li:not([hidden])", 3
    assert_select "#student_to_do li[hidden]", 2
    assert_select "#student_to_do button[data-reveal-target=button]", text: "Voir plus (2)"
    assert_select "#student_to_do a[href=?]", exercise_path(exercises.first.public_id), text: including("demain")
  end

  test "À faire: without any open exercise the section, its title included, is absent" do
    complete(assign_exercise("Fait", due_on: Date.current + 1))
    sign_in_as @student

    get student_home_path

    assert_select "#student_to_do, h2", text: tl("to_do.title"), count: 0
    assert_no_match(/Rien d'autre à faire/, response.body)
  end

  test "eleve-sans-prof CA-6: without a classroom, the announcements show; « À faire », the history and the invitation do not" do
    create_message(author: create_team_member(second_factor: false), title: "Rentrée", published_at: 1.hour.ago, audience: "all")
    remove(@student, @classroom, at: 10.days.ago)
    sign_in_as @student

    get student_home_path

    assert_equal %w[student_choose_class student_subjects student_home_announcements], css_select("#student_home [id]").map { it["id"] } & %w[student_choose_class student_subjects student_home_announcements]
    assert_select "#student_to_do, #student_invite_banner, turbo-frame#student_home_recent_activity", 0
  end

  test "eleve-sans-prof CA-3: never had a classroom: « Choisis ta classe » alone, no grid, no exercise of the day" do
    sign_in_as create_student

    get student_home_path

    assert_select "#student_choose_class"
    assert_select "#student_subjects, #student_next_step_daily_block, #student_next_step_daily, #student_class_card", 0
  end

  test "IL-17: a student whose classroom is archived sees « Choisis ta classe » on the home, without any warning" do
    student = create_student(classroom: create_classroom(status: "archived"), first_name: "Aya")
    sign_in_as student

    get student_home_path

    assert_choose_your_classroom
    assert_no_match REMOVED, response.body
  end

  test "IL-14: a student just removed lands on the home without a classroom, told why once, as a warning" do
    remove(@student, @classroom, at: 1.hour.ago)
    sign_in_as @student

    get student_home_path

    assert_choose_your_classroom
    assert_select "#toasts [data-toast-type=warning]", text: including(REMOVED)
    assert_equal REMOVED, tl("show.removed")

    get student_home_path

    assert_choose_your_classroom
    assert_no_match REMOVED, response.body
  end

  test "IL-14: removed again after coming back, the student is told again; a removal of more than 7 days says nothing" do
    remove(@student, @classroom, at: 1.hour.ago)
    sign_in_as @student
    get student_home_path
    Orm::ClassroomStudent.where(student: @student).update_all(left_at: nil, removed_at: nil, removed_by_id: nil)
    remove(@student, @classroom, at: 1.minute.ago)

    get student_home_path

    assert_select "#toasts", text: including(REMOVED)

    old = create_student(classroom: @classroom, first_name: "Aya")
    remove(old, @classroom, at: 8.days.ago)
    sign_out
    sign_in_as old

    get student_home_path

    assert_choose_your_classroom
    assert_no_match REMOVED, response.body
  end

  test "a teacher and the team receive 403" do
    [ create_teacher, create_team_member ].each do |user|
      sign_in_as user

      get student_home_path

      assert_response :forbidden
      sign_out
    end
  end

  # UDR-0066 §3.5 (amendement de l'UDR-0061 §3.3): the footer of the help sheet, « Plus sur Lnclass », carries « Blog »
  # from the first published article (BL-06), a plain link to /blog, which a signed-in student reads without redirect
  # (BL-20, test/integration/communication/articles_test.rb). The sheet itself opens in test/system/communication/help_sheet_test.rb.
  def help_sheet_footer_links
    css_select("dialog#help-sheet nav#help_sheet_links[aria-label='#{I18n.t('shared.help_sheet.footer.label')}'] li a")
      .map { [ it.text.squish, it["href"] ] }
  end

  test "BL-06: without a published article, the footer of the help sheet offers the mission and the legal pages, no « Blog »" do
    create_article(author: create_team_member(team_role: "content", second_factor: false), status: "draft")
    sign_in_as @student

    get student_home_path

    assert_equal [ [ "Notre mission", mission_path ], [ "Protection des données", privacy_path ],
                   [ "Conditions d'utilisation", terms_path ] ], help_sheet_footer_links
  end

  test "BL-06, BL-20: once an article is published, « Blog » leads the footer of the help sheet and links to the list" do
    create_article(title: "Réviser le BEPC en 4 semaines")
    sign_in_as @student

    get student_home_path

    assert_equal [ [ "Blog", blog_path ], [ "Notre mission", mission_path ], [ "Protection des données", privacy_path ],
                   [ "Conditions d'utilisation", terms_path ] ], help_sheet_footer_links
  end

  # UDR-0071 §3.5 (Lot B of the annonces chantier, ADR-0078 §4.3): the announcements of the student, second section of the
  # home, after « À faire »: the direction, then the teachers, then the team, five at most, the dismissed ones left out.
  def announce(author, title, at: 1.hour.ago, **)
    create_message(author:, title:, published_at: at, **)
  end

  def announcement_titles = css_select("#student_home_announcements li article h3").map(&:text)

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end

  test "AN-10 — the carousel after the grid and before the history: the direction, the teachers newest first, the team; five cards, then the link" do
    teacher = create_teacher(school: @classroom.school, classrooms: [ @classroom ])
    team = create_team_member(second_factor: false)
    announce(create_school_admin(school: @classroom.school), "Devoirs communs", at: 5.hours.ago, school: @classroom.school)
    [ [ "Fiches 1", 3 ], [ "Fiches 3", 1 ], [ "Fiches 2", 2 ] ].each do |title, hours|
      announce(teacher, title, at: hours.hours.ago, audience: "classrooms", classrooms: [ @classroom ])
    end
    announce(team, "Rentrée ancienne", at: 4.hours.ago, audience: "all")
    announce(team, "Rentrée numérique", at: 30.minutes.ago, audience: "all")
    sign_in_as @student

    get student_home_path

    order = %w[student_class_card student_subjects student_home_announcements student_home_recent_activity]
    assert_equal order, css_select("#student_home [id]").map { it["id"] } & order
    assert_equal [ "Devoirs communs", "Fiches 3", "Fiches 2", "Fiches 1", "Rentrée numérique" ], announcement_titles
  end

  # UDR-0071, amendment of 2026-10-06: the announcements live on the home; no « Toutes les annonces » under the band.
  test "AN-22 — the carousel of the student has no « Toutes les annonces »" do
    announce(create_team_member(second_factor: false), "Rentrée numérique", audience: "all")
    sign_in_as @student

    get student_home_path

    assert_select "#student_home_announcements article h3", "Rentrée numérique"
    assert_select "a[href=?]", announcements_path, 0
  end

  test "AN-11 — no announcement for the student: no announcements band at all" do
    announce(create_team_member(second_factor: false), "Pour les enseignants", audience: "teachers")
    sign_in_as @student

    get student_home_path

    assert_select "#student_home_announcements", 0
  end

  # UDR-0071, amendment of 2026-10-06: all dismissed, the section stays for screen readers only (the target of « Annuler »),
  # without a link.
  test "AN-12 — a dismissed announcement is out of the carousel, on any device; all dismissed, screen readers only" do
    team = create_team_member(second_factor: false)
    dismissed = announce(team, "Rentrée numérique", audience: "all")
    announce(team, "Concours", audience: "all", at: 2.hours.ago)
    dismiss_message(message: dismissed, user: @student)
    sign_in_as @student

    get student_home_path

    assert_equal [ "Concours" ], announcement_titles

    dismiss_message(message: Orm::Message.find_by!(title: "Concours"), user: @student)
    get student_home_path

    assert_select "#student_home_announcements.sr-only" do
      assert_select "ul", 0
      assert_select "p", I18n.t("communication.inboxes.carousel.all_dismissed")
    end
    assert_select "a[href=?]", announcements_path, 0
  end

  # UDR-0075 §3.1 and §3.2 (annonces-v2, Lot B): the card of the carousel takes the theme of its message; a drawing of the
  # team is rebuilt in the strong colour of the theme.
  test "AV-07, AV-08 — the carousel shows each card in its theme, with its drawing of the team" do
    team = create_team_member(second_factor: false)
    bus = create_illustration(name: "Bus scolaire", created_by: team)
    sortie = announce(team, "Sortie", audience: "all", theme: "mangue", illustration: bus)
    rentree = announce(team, "Rentrée numérique", audience: "all", at: 2.hours.ago)
    sign_in_as @student

    get student_home_path

    assert_select "#student_home_announcements li article#announcement_#{sortie.public_id}[data-announcement-theme=mangue]" do
      assert_select "svg.fill-brand-strong[viewBox='0 0 64 64'] > rect"
    end
    assert_select "#student_home_announcements li article#announcement_#{rentree.public_id}[data-announcement-theme=ciel]"
  end

  # AV-08: the drawings of the team come in one query, whatever the number of cards that carry one.
  test "ADR-0067 — the home costs the same number of queries with one announcement or with six" do
    team = create_team_member(second_factor: false)
    drawings = Array.new(2) { |index| create_illustration(name: "Dessin #{index}", created_by: team) }
    sign_in_as @student
    announce(team, "Annonce 0", audience: "all", theme: "mangue", illustration: drawings.first)
    get student_home_path
    one = count_queries { get student_home_path }
    5.times do |index|
      announce(team, "Annonce #{index + 1}", audience: "all", theme: Entities::Communication::Message::THEMES[index],
                                             illustration: index.even? ? drawings[index % 2] : "info")
    end

    assert_equal one, count_queries { get student_home_path }
    assert_equal 5, announcement_titles.size
  end

  # Chantier entree-et-accueil-eleve-allegees, Lot D (UDR accueil-eleve-qr-fenetre-inviter §3.2) : « Ton premier exercice » est une
  # fenêtre du shell (StudentFirstExercisesControllerTest) ; l'accueil n'en garde plus la carte, et ne retire plus rien de ses listes.
  FIRST = "#student_first_exercise".freeze

  test "CA-12: not activated, the home has no « Ton premier exercice » card, only the deferred frame of the window" do
    create_exercise(essential: @essential, title: "Les étapes de la méiose")
    sign_in_as @student

    get student_home_path

    ids = css_select("#student_home [id]").map { it["id"] } & %w[student_class_card student_first_exercise student_subjects student_invite_classmates]
    assert_equal %w[student_class_card student_subjects student_invite_classmates], ids
    assert_select FIRST, 0
    assert_select "turbo-frame#student_first_exercise_prompt[src=?]", student_first_exercise_path
  end

  test "CA-16: the « Inviter » tile follows « Mes matières », in the format of its tiles, and sends to the class share" do
    sign_in_as @student

    get student_home_path

    ids = css_select("#student_home [id]").map { it["id"] } & %w[student_subjects student_invite_classmates]
    assert_equal %w[student_subjects student_invite_classmates], ids
    # Retouche accueil-eleve-marges-wave : dès lg, « Invite tes camarades » ne colle plus au libellé des matières.
    assert_select "div[class~='lg:pt-6'] > section#student_invite_classmates"
    assert_select "section#student_invite_classmates[aria-labelledby=student_invite_classmates_title]" do
      assert_select "h2#student_invite_classmates_title", text: tl("invite_tile.title")
      assert_select "form[action=?][method=post][target=_blank][data-turbo=false]", class_invite_path do
        assert_select "button#student_invite_tile[aria-label=?]", tl("invite_tile.action_label", classroom: "Tle D 1") do
          assert_select "span.size-14.rounded-full.bg-brand-soft.text-brand-strong svg"
          assert_select "span", text: tl("invite_tile.action")
        end
      end
      assert_select "section .ui-button-secondary", 0
    end
  end

  test "activation CA-9: the assignment stays in « À faire », whoever the student, whichever the first exercise" do
    brought = create_student(classroom: @classroom, joined_via: "code")
    @student = brought
    assign_exercise("Méiose, les étapes", due_on: Date.current + 2)
    assign_exercise("Mitose", due_on: Date.current + 3)
    sign_in_as brought

    get student_home_path

    assert_select "#student_to_do li", 2
    assert_select FIRST, 0
  end

  # Activation-eleve (UDR-0174 §3) : l'historique, porte du retour.
  def history = get(student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" })

  test "activation CA-11: an activated student finds his copy in progress in the history; the whole line resumes it" do
    complete(create_exercise(essential: @essential), score: 80)
    exercise = create_exercise(essential: @essential, title: "Mitose", questions: 5)
    copy = create_exercise_session(student: @student, exercise:, answered_count: 2)
    sign_in_as @student

    history

    assert_select "turbo-frame#student_home_recent_activity li", 2
    assert_select "a[href=?][aria-label=?]", exercise_session_path(copy.public_id), tl("history.resume_label", title: "Mitose") do
      assert_select "[data-progress]", text: tl("history.in_progress", answered: 2, total: 5)
    end
    assert_select "form[action=?]", exercise_sessions_path(exercise.public_id), 0
  end

  test "activation CA-12: a copy completed at 16/20, out of the pause, can be done again" do
    exercise = create_exercise(essential: @essential, title: "Méiose")
    complete(exercise, score: 80)
    sign_in_as @student

    history

    assert_select "form[action=?] button[aria-label=?]", exercise_sessions_path(exercise.public_id), tl("history.redo_label", title: "Méiose"),
                  text: tl("history.redo")
  end

  test "activation CA-13 (Lot D): the card is gone, so the copy in progress is in the history like any other" do
    copy = create_exercise_session(student: @student, exercise: create_exercise(essential: @essential, title: "Mitose"), answered_count: 1)
    complete(create_exercise(essential: @essential, title: "Méiose"), score: 20)
    sign_in_as @student

    history

    assert_select "a[href=?]", exercise_session_path(copy.public_id)
    assert_select "turbo-frame#student_home_recent_activity li", 2
  end

  test "activation CA-14: neither completed nor in progress (an abandoned copy only): no history" do
    create_exercise_session(student: @student, exercise: create_exercise(essential: @essential), status: "abandoned")
    sign_in_as @student

    history

    assert_equal "", css_select("turbo-frame#student_home_recent_activity").text.strip
  end

  test "activation: « Voir plus (n) » counts the completed copies Mon historique lists, not the copies in progress" do
    complete(create_exercise(essential: @essential), score: 80).update!(completed_at: 1.hour.ago)
    2.times { create_exercise_session(student: @student, exercise: create_exercise(essential: @essential), started_at: 10.minutes.ago) }
    complete(create_exercise(essential: @essential), score: 80).update!(completed_at: 2.hours.ago)
    sign_in_as @student

    history

    assert_select "turbo-frame#student_home_recent_activity li", 3
    assert_select "a#student_history_more", text: "Voir plus (1)"

    # Au-delà des 3 lignes, une copie en cours seulement : pas de « Voir plus ».
    Orm::ExerciseSession.where(status: "completed", student: @student).order(:completed_at).first.update_columns(status: "abandoned", score_percent: nil, completed_at: nil)
    create_exercise_session(student: @student, exercise: create_exercise(essential: @essential), started_at: 3.hours.ago)
    history
    assert_select "a#student_history_more", 0
  end
end

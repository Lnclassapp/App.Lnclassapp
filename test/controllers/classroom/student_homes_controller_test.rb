require "test_helper"

# CL-23, TR-04, AS-36, TR-02 (UDR-0010, UDR-0058 §3.3): the student home. The old feed raised NameError as soon as the student had a
# classroom, and a student without a classroom bounced between / and /students forever.
class Classroom::StudentHomesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom(name: "Tle D 1", join_code: "kfm37", school: create_school(name: "Lycée Classique"),
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

  test "the student sees their classroom, its code in capitals, and no classmate by name" do
    create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yapo")
    sign_in_as @student

    get student_home_path

    assert_response :success
    assert_select "h1", text: including(tl("show.greeting", name: "Aya"))
    # UDR-0058 §3.3, R6: the classroom card already says the school and the classroom, the header says them no more.
    assert_select "h1 + p", 0
    assert_select "#student_home_classroom", text: including("KFM37")
    assert_select "#student_home_classroom", text: including("Lycée Classique")
    assert_select "#student_home_classroom", text: including(tl("classroom_card.students", count: 2))
    assert_no_match "Yapo", response.body
    assert_no_match "Koffi", response.body
  end

  # UDR-0076 §3.1 (CA-1): the classroom, the subjects, the announcements, « À faire », then the recent activity; the
  # « Cours » card is gone, the subjects lead to the catalogue.
  test "the home reads classroom, subjects, announcements, « À faire », then the recent activity" do
    assign_together(create_exercise(essential: @essential, title: "Méiose, les étapes"))
    create_message(author: create_team_member(second_factor: false), title: "Rentrée", published_at: 1.hour.ago, audience: "all")
    sign_in_as @student

    get student_home_path

    assert_equal %w[student_home_classroom student_home_subjects student_home_announcements student_home_exercises
                    student_home_activity], css_select("#student_home > [id]").map { it["id"] }
    assert_no_match "Voir les cours", response.body
  end

  # UDR-0076 §3.1 (CA-2): one bubble per subject with a published course of the student's level, in the order of the
  # charter, each to the catalogue filtered on it; a draft course or a course of another level brings no bubble.
  test "« Mes matières »: a bubble per subject of the student's level, to the filtered catalogue, in the charter order" do
    maths = create_material(name: "Mathématiques")
    create_course(material: maths, level: @classroom.level)
    create_course(material: create_material(name: "Français", category: "literature"), level: create_level)
    create_course(material: create_material(name: "Philosophie", category: "literature"), level: @classroom.level, status: "draft")
    sign_in_as @student

    get student_home_path

    assert_equal %w[subject_mathematiques subject_svt], css_select("#student_home_subject_bubbles li a").map { it["id"] }
    assert_select "#student_home_subjects nav#student_home_subject_bubbles[aria-label=?]", tl("subjects.label") do
      assert_select "a#subject_mathematiques[href=?]", courses_path(material: "mathematiques"), text: including("Mathématiques")
      assert_select "a#subject_svt[href=?]", courses_path(material: "svt"), text: including("SVT")
      assert_select "a#subject_svt img[src*='subjects/svt']"
    end
    # UDR-0069, amendment of 2026-10-06: no « Tous les cours » any more, the Cours tab leads there.
    assert_select "#student_home_subjects a[href=?]", courses_path, 0
    assert_no_match(/subject_francais|subject_philosophie/, response.body)
  end

  # UDR-0076 §3.1, UDR-0062 §3.3 (CA-3): the amber dot only on the subject of a late exercise, said in words too.
  test "the bubble of a subject with a late exercise carries the amber dot, the others none" do
    create_course(material: create_material(name: "Mathématiques"), level: @classroom.level)
    late = create_exercise(essential: @essential, title: "Méiose, en retard")
    create_assignment(classroom: @classroom, assignable: late, assigned_at: 4.days.ago, due_on: Time.zone.today - 2)
    sign_in_as @student

    get student_home_path

    assert_select "a#subject_svt span.bg-warning[aria-hidden=true]", 1
    assert_select "a#subject_svt .sr-only", text: tl("subjects.late")
    assert_select "a#subject_mathematiques span.bg-warning", 0
  end

  test "a late exercise already done brings no dot" do
    done = create_exercise(essential: @essential)
    create_assignment(classroom: @classroom, assignable: done, assigned_at: 4.days.ago, due_on: Time.zone.today - 2)
    create_exercise_session(student: @student, exercise: done, status: "completed", score_percent: 75)
    sign_in_as @student

    get student_home_path

    assert_select "a#subject_svt span.bg-warning", 0
  end

  test "no published course at the student's level: the empty subjects, and the link to every course" do
    classroom = create_classroom(level: create_level)
    sign_in_as create_student(classroom:)

    get student_home_path

    assert_select "#student_home_subjects" do
      assert_select "nav", 0
      assert_select "*", text: tl("subjects.empty")
      assert_select "a[href=?]", courses_path, 0
    end
  end

  # ADR-0076 §4.1 (CA-8): the home is personal; the browser keeps it private, no shared cache ever does.
  test "ADR-0076 — the home is never public in a cache" do
    sign_in_as @student

    get student_home_path

    assert_match(/private|no-store/, response.headers["Cache-Control"])
    assert_no_match(/public/, response.headers["Cache-Control"])
  end

  # UDR-0058 §3.3: a line keeps its title, its subject and one button; badge, best score, mastery and sessions live on
  # the exercise page, which the title opens (UDR-0057 §2.4). The first button of the list is the primary one, the next ones are secondary (UDR-0057 R1).
  # UDR-0062 §3.2: the exercise already completed once goes after the one not completed yet.
  test "each assigned exercise with its title, its subject and one button, the first one primary" do
    started = create_exercise(essential: @essential, title: "Méiose, les étapes")
    fresh = create_exercise(essential: @essential, title: "Méiose, le bilan")
    assign_together(started, fresh)
    best = create_exercise_session(student: @student, exercise: started, status: "completed", score_percent: 80)
    create_badge(student: @student, exercise: started, level: "gold", session: best)
    session = create_exercise_session(student: @student, exercise: started)
    sign_in_as @student

    get student_home_path

    assert_select "#student_home_exercises li", 2
    assert_select "#student_home_exercises li:first-child" do
      assert_select "a[href='#{exercise_path(fresh.public_id)}']", text: "Méiose, le bilan"
      assert_select "*", text: "SVT"
      assert_select "a, button", 2
      assert_select "form[action='#{exercise_sessions_path(fresh.public_id)}'][method=post] button.#{PRIMARY}",
                    text: including(tl("assigned_exercise.start"))
    end
    assert_select "#student_home_exercises li:last-child" do
      assert_select "a[href='#{exercise_path(started.public_id)}']", text: "Méiose, les étapes"
      assert_select "a, button", 2
      assert_select "a.#{SECONDARY}[href='#{exercise_session_path(session.public_id)}']", text: including(tl("assigned_exercise.resume"))
    end
    assert_select "#student_home_exercises", text: including(I18n.t("assessment.badges.levels.gold")), count: 0
    assert_select "#student_home_exercises", text: including("80 %"), count: 0
    assert_select "#student_home_exercises", text: including(I18n.t("assessment.badges.mastery.acquired")), count: 0
    assert_select "#student_home_exercises", text: including("session"), count: 0
  end

  # PRD « Accueil élève », UDR-0062 §3.1 and §3.2: the due date is a label under the title, beside the subject, amber only
  # today, tomorrow and once passed; a late exercise can still be started.
  test "the due date under the title, amber only when it is today, tomorrow or passed" do
    exercise = create_exercise(essential: @essential, title: "Méiose — QCM")
    create_assignment(classroom: @classroom, assignable: exercise, assigned_at: Time.zone.local(2026, 10, 2, 9),
                      due_on: Date.new(2026, 10, 8))

    { 5 => [ "À rendre jeudi", :neutral ], 7 => [ "À rendre demain", :warning ], 8 => [ "À rendre aujourd'hui", :warning ],
      9 => [ "En retard · prévu hier", :warning ], 12 => [ "En retard · prévu jeudi 8 oct.", :warning ] }.each do |day, (label, tone)|
      travel_to Time.zone.local(2026, 10, day, 10) do
        sign_in_as @student

        get student_home_path

        assert_select "#student_home_exercises li:first-child div.flex-wrap", 1 do
          assert_select "span", text: "SVT"
          assert_select "span.#{ComponentsHelper::BADGE_TONES.fetch(tone)[:chip].tr(' ', '.')}", text: label
        end
        assert_select "#student_home_exercises li:first-child form[action='#{exercise_sessions_path(exercise.public_id)}'] button.#{PRIMARY}",
                      text: including(tl("assigned_exercise.start"))
        sign_out
      end
    end
  end

  # PRD « Accueil élève »: due the 8th, due the 12th, then without a due date; the completed one last and without a date.
  test "the most urgent exercise first, with the only primary button; a completed one last, without a date" do
    travel_to Time.zone.local(2026, 10, 6, 10) do
      undated = create_exercise(essential: @essential, title: "Sans échéance")
      later = create_exercise(essential: @essential, title: "Dû le 12")
      sooner = create_exercise(essential: @essential, title: "Dû le 8")
      done = create_exercise(essential: @essential, title: "Terminé")
      create_assignment(classroom: @classroom, assignable: undated, assigned_at: 1.day.ago)
      create_assignment(classroom: @classroom, assignable: later, assigned_at: 1.hour.ago, due_on: Date.new(2026, 10, 12))
      create_assignment(classroom: @classroom, assignable: sooner, assigned_at: 4.days.ago, due_on: Date.new(2026, 10, 8))
      create_assignment(classroom: @classroom, assignable: done, assigned_at: 3.days.ago, due_on: Date.new(2026, 10, 5))
      session = create_exercise_session(student: @student, exercise: sooner)
      create_exercise_session(student: @student, exercise: done, status: "completed", score_percent: 70)
      sign_in_as @student

      get student_home_path

      assert_equal [ "Dû le 8", "Dû le 12", "Sans échéance", "Terminé" ],
                   css_select("#student_home_exercises li a[href^='/exercises/']").map { it.text.squish }
      assert_select "#student_home_exercises .#{PRIMARY}", 1
      assert_select "#student_home_exercises li:first-child a.#{PRIMARY}[href='#{exercise_session_path(session.public_id)}']"
      assert_select "#student_home_exercises li:nth-child(1)", text: including("À rendre jeudi")
      assert_select "#student_home_exercises li:nth-child(2)", text: including("À rendre lundi")
      assert_select "#student_home_exercises li:nth-child(3)", text: /À rendre|En retard/, count: 0
      assert_select "#student_home_exercises li:last-child", text: /À rendre|En retard/, count: 0
    end
  end

  # UDR-0058 §3.3, R4: the badges and mastery are explained on the exercise page, not under « À faire ».
  test "no help block under « À faire »" do
    create_assignment(classroom: @classroom, assignable: create_exercise(essential: @essential))
    sign_in_as @student

    get student_home_path

    assert_select "#student_home_help", 0
    assert_select "#student_home_exercises", text: /Badges|Maîtrise/, count: 0
  end

  # UDR-0057 R3: 3 lines, the next ones rendered hidden, then « Voir plus », without a request.
  test "the exercises show 3 lines, then « Voir plus » over the hidden ones" do
    assign_together(*Array.new(4) { |index| create_exercise(essential: @essential, title: "Exercice #{index + 1}") })
    sign_in_as @student

    get student_home_path

    assert_select "#student_home_exercises[data-controller=reveal]" do
      assert_select "li[data-reveal-target=item]", 4
      assert_select "li[hidden]", 1
      assert_select "li:last-child[hidden]", text: including("Exercice 4")
      assert_select "button[data-reveal-target=button]", text: including(I18n.t("components.reveal.more"))
    end
  end

  test "3 exercises or fewer: no « Voir plus »" do
    assign_together(*Array.new(3) { create_exercise(essential: @essential) })
    sign_in_as @student

    get student_home_path

    assert_select "#student_home_exercises li", 3
    assert_select "#student_home_exercises li[hidden]", 0
    assert_select "#student_home_exercises button", text: including(I18n.t("components.reveal.more")), count: 0
  end

  test "no exercise assigned, no sheet to review: the empty state, without the review section" do
    sign_in_as @student

    get student_home_path

    assert_select "#student_home_exercises", text: including(tl("show.todo_empty"))
    assert_select "#student_home_gaps", 0
  end

  test "the sheets to review link to their sheet" do
    create_gap(student: @student, essential: @essential)
    sign_in_as @student

    get student_home_path

    assert_select "#student_home_gaps", text: including(tl("pending_gaps.title"))
    assert_select "#student_home_gaps a[href='#{course_essential_path(@course.slug, @essential.slug)}']", text: "La méiose"
    assert_select "#student_home_gaps button", text: including(I18n.t("components.reveal.more")), count: 0
  end

  test "the sheets to review show 3 lines, then « Voir plus » over the hidden ones" do
    4.times { |index| create_gap(student: @student, essential: create_essential(course: @course, name: "Fiche #{index + 1}")) }
    sign_in_as @student

    get student_home_path

    assert_select "#student_home_gaps [data-controller=reveal]" do
      assert_select "li[data-reveal-target=item]", 4
      assert_select "li[hidden]", 1
      assert_select "button[data-reveal-target=button]", text: including(I18n.t("components.reveal.more"))
    end
  end

  test "the recent activity is a lazy frame, then its frame alone with the last completed sessions" do
    exercise = create_exercise(essential: @essential, title: "Méiose")
    session = create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 90)
    sign_in_as @student

    get student_home_path

    assert_select "turbo-frame#student_home_recent_activity[loading=lazy][src='#{student_home_path}']"
    assert_no_match "Méiose", response.body

    get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }

    assert_response :success
    assert_select "turbo-frame#student_home_recent_activity[target=_top]" do
      assert_select "a[href='#{exercise_session_result_path(session.public_id)}']", text: including("Méiose")
      assert_select "*", text: including(I18n.t("assessment.badges.grade", grade: 18))
    end
    assert_no_match "KFM37", response.body
  end

  # UDR-0058 §3.3, R6: one form of the grade, out of 20 in the chip; neither the percentage nor the mastery.
  test "an activity line shows the grade out of 20 once, its title and when, then 3 lines and « Voir plus »" do
    exercise = create_exercise(essential: @essential, title: "Méiose")
    4.times { create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 90) }
    sign_in_as @student

    get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }

    assert_select "turbo-frame#student_home_recent_activity [data-controller=reveal]" do
      assert_select "li[data-reveal-target=item]", 4
      assert_select "li[hidden]", 1
      assert_select "li:first-child" do
        assert_select "*", text: I18n.t("assessment.badges.grade", grade: 18), count: 1
        assert_select "*", text: including("Méiose")
      end
      assert_select "button[data-reveal-target=button]", text: including(I18n.t("components.reveal.more"))
    end
    assert_select "turbo-frame#student_home_recent_activity", text: including("90 %"), count: 0
    assert_select "turbo-frame#student_home_recent_activity", text: including(I18n.t("assessment.badges.mastery.acquired")), count: 0
  end

  test "no completed session: the empty activity" do
    sign_in_as @student

    get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }

    assert_select "turbo-frame#student_home_recent_activity", text: including(tl("recent_activity.empty"))
  end

  test "a student without an active classroom: one redirection, to a page that answers" do
    sign_in_as create_student

    get student_home_path

    assert_redirected_to pending_account_path
    follow_redirect!
    assert_response :success
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

  test "AN-10 — the carousel before « À faire » (UDR-0076): the direction, the teachers newest first, the team; five cards, then the link" do
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

    assert_equal %w[student_home_classroom student_home_subjects student_home_announcements student_home_exercises],
                 css_select("#student_home > [id]").map { it["id"] }.first(4)
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
end

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


  CARD = "section#student_next_step".freeze

  def assign_exercise(title, due_on: nil, assigned_at: 3.days.ago, **)
    exercise = create_exercise(essential: @essential, title:)
    create_assignment(classroom: @classroom, assignable: exercise, assigned_at:, due_on:, **)
    exercise
  end

  def complete(exercise, score: 80) = create_exercise_session(student: @student, exercise:, status: "completed", score_percent: score)

  def card_buttons = css_select("#{CARD} .ui-button-primary, #{CARD} .ui-button-secondary")

  test "CA-D1: the band, the card, the grid, the history in this order; no bottom bar, no « À faire ensuite », no « Paiement »" do
    assign_exercise("Méiose, les étapes", due_on: Date.current + 2)
    create_message(author: create_team_member(second_factor: false), title: "Rentrée", published_at: 1.hour.ago, audience: "all")
    sign_in_as @student

    get student_home_path

    assert_response :success
    assert_select "h1.sr-only", text: tl("show.page_title")
    assert_equal %w[student_next_step student_subjects student_home_announcements student_history],
                 css_select("#student_home > [id]").map { it["id"] }
    # The band is the shell's, above the column, and the page title is not repeated.
    assert_select "main > div.lg\\:hidden > header.student-band.bg-brand.text-band-ink"
    assert_select "header.sticky.max-lg\\:hidden"
    assert_select "[class*='fixed bottom-0'], nav.fixed", 0
    assert_no_match(/À faire ensuite|Paiement/, response.body)
    assert_no_match "Bonjour", css_select("#main").text
    assert_select "#student_next_step_title", text: "Méiose, les étapes"
  end

  test "the page of another role keeps its header on every size: only the pages with a band hide it under lg" do
    sign_in_as @student

    get courses_path

    assert_select "header.sticky"
    assert_select "header.sticky.max-lg\\:hidden", 0
  end

  test "CA-D2: two late exercises and one due Saturday: the oldest late one, « En retard · date », 1 other, « Le faire maintenant »" do
    assign_exercise("Retard récent", due_on: Date.yesterday)
    assign_exercise("Retard ancien", due_on: Date.current - 3, assigned_at: 5.days.ago)
    assign_exercise("Pour samedi", due_on: Date.current + 3)
    sign_in_as @student

    get student_home_path

    assert_select "#{CARD}[data-state=late]" do
      assert_select "#student_next_step_title", text: "Retard ancien"
      assert_select "span.bg-warning-soft.text-warning", text: /En retard/
      assert_select "a[href=?]", student_classroom_path, text: including(tl("next_step.late.others", count: 1))
      assert_select "form[action=?] button.ui-button-primary", exercise_sessions_path(Orm::Exercise.find_by!(title: "Retard ancien").public_id),
                    text: tl("next_step.late.start")
    end
    assert_equal 1, card_buttons.size
  end

  test "CA-D2: the card signs the exercise with the subject and the teacher, 4 exercises done out of 6 written once" do
    teacher = create_teacher(last_name: "Kouassi", gender: "male")
    assign_exercise("Pour samedi", due_on: Date.current + 3, by: teacher)
    3.times { |index| complete(assign_exercise("Fait #{index}", due_on: Date.current + 1)) }
    sign_in_as @student

    get student_home_path

    assert_select "#{CARD} p", text: "SVT · M. Kouassi"
    assert_select "#{CARD} p", text: tl("next_step.progress", count: 3, total: 4), count: 1
    assert_select "#{CARD} [role=progressbar][aria-valuenow='3'][aria-valuemax='4']"
  end

  test "CA-D3: no late exercise: the nearest due date, « Commencer l'exercice », or « Reprendre » when a session is open" do
    assign_exercise("Dans quatre jours", due_on: Date.current + 4)
    near = assign_exercise("Demain", due_on: Date.current + 1)
    sign_in_as @student

    get student_home_path

    assert_select "#{CARD}[data-state=due]" do
      assert_select "#student_next_step_title", text: "Demain"
      assert_select "form[action=?] button.ui-button-primary", exercise_sessions_path(near.public_id), text: tl("next_step.due.start")
      assert_select "a", text: including(tl("next_step.late.others", count: 1)), count: 0
    end

    session = create_exercise_session(student: @student, exercise: near)
    get student_home_path

    assert_select "#{CARD} a.ui-button-primary[href=?]", exercise_session_path(session.public_id), text: tl("next_step.due.resume")
    assert_select "#{CARD} form button", 0
  end

  test "CA-D4: all assigned done and a sheet to review: the oldest sheet, its mark, « Revoir la fiche » to the sheet" do
    complete(assign_exercise("Fait", due_on: Date.current + 1))
    create_gap(student: @student, essential: create_essential(course: @course, name: "Ancienne fiche"), created_at: 3.days.ago,
               source_session: complete(create_exercise(essential: @essential), score: 40))
    create_gap(student: @student, essential: create_essential(course: @course, name: "Fiche récente"), created_at: 1.day.ago)
    sign_in_as @student

    get student_home_path

    assert_select "#{CARD}[data-state=review]" do
      assert_select "#student_next_step_title", text: "Ancienne fiche"
      assert_select "span", text: tl("next_step.review.badge")
      assert_select "p", text: tl("next_step.review.note", grade: "8/20")
      assert_select "a.ui-button-primary[href=?][data-turbo-prefetch=false]", course_essential_path(@course.slug, Orm::Essential.find_by!(name: "Ancienne fiche").slug),
                    text: tl("next_step.review.open")
    end
  end

  test "CA-D5: all done, nothing to review: « Tout est fait ! », the exercise of the day in a secondary button" do
    complete(assign_exercise("Fait", due_on: Date.current + 1))
    daily = create_exercise(essential: create_essential(course: create_course(material: create_material(name: "Français", category: "literature"),
                                                                                level: @classroom.level)), title: "Les accords")
    sign_in_as @student

    get student_home_path

    assert_select "#{CARD}[data-state=all_done]" do
      assert_select "#student_next_step_title", text: tl("next_step.all_done.title")
      assert_select "p", text: tl("next_step.progress", count: 1, total: 1)
      assert_select "#student_next_step_daily_block", text: including("Les accords")
      assert_select "form[action=?] button.ui-button-secondary", exercise_sessions_path(daily.public_id), text: tl("next_step.all_done.start")
    end
    assert_equal 1, card_buttons.size
    assert_select "#{CARD} .ui-button-primary", 0
  end

  test "CA-D5: all done and the exercise of the day already done: « Reviens demain ! » and no button" do
    complete(assign_exercise("Fait", due_on: Date.current + 1))
    create_exercise(essential: @essential, title: "Du jour")
    sign_in_as @student
    get student_home_path
    daily_id = css_select("#{CARD} form").first["action"][%r{/exercises/([^/]+)/sessions}, 1]
    complete(Orm::Exercise.find_by!(public_id: daily_id))

    get student_home_path

    assert_select "#{CARD}[data-state=all_done] #student_next_step_daily[data-state=done_today]", text: including(tl("next_step.all_done.done_today"))
    assert_select "#{CARD} form", 0
    assert_select "#{CARD} .ui-button-primary, #{CARD} .ui-button-secondary", 0
  end

  test "CA-D6: nothing assigned: the exercise of the day and the invitation of the teacher to WhatsApp" do
    daily = create_exercise(essential: @essential, title: "La méiose en bref")
    sign_in_as @student

    get student_home_path

    assert_select "#{CARD}[data-state=unassigned]" do
      assert_select "#student_next_step_title", text: "La méiose en bref"
      assert_select "span", text: "#{tl('next_step.unassigned.badge')} · Lnclass"
      assert_select "form[action=?] button.ui-button-primary", exercise_sessions_path(daily.public_id), text: tl("next_step.unassigned.start")
      message = tl("invite_teacher.message", classroom: "Tle D 1", school: "Lycée Classique", link: new_teacher_registration_url)
      assert_select "a#student_next_step_invite[href=?][target=_blank][rel~=noopener]", "https://wa.me/?text=#{ERB::Util.url_encode(message)}",
                    text: including(tl("next_step.unassigned.invite"))
    end
  end

  test "CA-D6: nothing to propose today: the sentence, no button; the invitation stays" do
    sign_in_as @student

    get student_home_path

    assert_select "#{CARD}[data-state=unassigned] #student_next_step_daily", text: including(tl("next_step.unassigned.none"))
    assert_equal 0, card_buttons.size
    assert_select "#student_next_step_invite"
  end

  test "CA-D9: the header of the card, « 3E B · CM1T ›», opens Ma classe; the sigle of the school, else its name" do
    @classroom.school.update!(sigle: "CM1T")
    sign_in_as @student

    get student_home_path

    assert_select "#{CARD} a[href=?]", student_classroom_path do
      assert_select "span.truncate", text: "Tle D 1 · CM1T"
      assert_select ".uppercase"
      assert_select "svg"
    end

    @classroom.school.update!(sigle: nil)
    get student_home_path

    assert_select "#{CARD} a[href=?] span.truncate", student_classroom_path, text: "Tle D 1 · Lycée Classique"
  end

  test "CA-D7: no classroom: « Choisis ta classe », the code field, « Rejoindre », « Je n'ai pas de code »; grid, announcements, history hidden" do
    sign_in_as create_student(classroom: create_classroom(status: "archived"))

    get student_home_path

    assert_response :success
    assert_select "#{CARD}[data-state=no_classroom]" do
      assert_select "#student_next_step_title", text: tl("no_classroom.title")
      assert_select "form#student-home-code-form[action=?][method=post]", student_classroom_choices_path do
        assert_select "input[name='student_classroom_choice[join_code]'][maxlength='6']"
        assert_select "button[type=submit]", text: tl("no_classroom.submit")
      end
      assert_select "a#student_next_step_no_code[href=?]", new_student_classroom_choice_path, text: tl("no_classroom.no_code")
      assert_select "a[href=?]", student_classroom_path, 0
    end
    assert_select "#student_subjects, #student_history, #student_home_announcements, turbo-frame#student_home_recent_activity", 0
    assert_select "header.sticky.max-lg\\:hidden"
  end

  test "CA-D7: the archive is offered beside the code to a student who has one, to no one else" do
    sign_in_as create_student(classroom: create_classroom(status: "archived"))
    get student_home_path
    assert_select "#{CARD} a[href=?]", student_archive_path, text: tl("no_classroom.archive")

    sign_out
    sign_in_as create_student
    get student_home_path
    assert_select "#{CARD}[data-state=no_classroom]"
    assert_select "#{CARD} a[href=?]", student_archive_path, 0
  end

  test "CA-D8: the subject of a late exercise carries the amber dot and the words, the others none" do
    create_course(material: create_material(name: "Mathématiques"), level: @classroom.level)
    assign_exercise("Méiose, en retard", due_on: Date.current - 2, assigned_at: 4.days.ago)
    sign_in_as @student

    get student_home_path

    assert_select "a#subject_svt span.bg-warning-dot[aria-hidden=true]", 1
    assert_select "a#subject_svt .sr-only", text: tl("subjects.late")
    assert_select "a#subject_mathematiques span.bg-warning-dot", 0
    assert_select "a#subject_mathematiques .sr-only", 0
  end

  test "a late exercise already done brings no dot" do
    done = assign_exercise("Fait en retard", due_on: Date.current - 2, assigned_at: 4.days.ago)
    complete(done)
    sign_in_as @student

    get student_home_path

    assert_select "a#subject_svt span.bg-warning-dot", 0
  end

  test "the grid: a round per subject of the student's level, in the charter order, the full names, then « Inviter » to WhatsApp" do
    create_course(material: create_material(name: "Physique-Chimie"), level: @classroom.level)
    create_course(material: create_material(name: "Histoire-Géographie", category: "literature"), level: @classroom.level)
    maths = create_material(name: "Mathématiques")
    create_course(material: maths, level: @classroom.level)
    create_course(material: create_material(name: "Français", category: "literature"), level: create_level)
    create_course(material: create_material(name: "Philosophie", category: "literature"), level: @classroom.level, status: "draft")
    sign_in_as @student

    get student_home_path

    ids = css_select("#student_subjects li a").map { it["id"] }
    assert_equal %w[subject_histoire-geographie subject_mathematiques subject_physique-chimie subject_svt], ids.first(4).sort
    assert_equal "subject_invite", ids.last
    assert_equal 5, ids.size
    assert_select "nav#student_subjects[aria-label=?]", tl("subjects.label") do
      assert_select "ul.grid-cols-4"
      assert_select "a#subject_physique-chimie[href=?]", courses_path(material: "physique-chimie"), text: "Physique-Chimie"
      assert_select "a#subject_histoire-geographie", text: "Histoire-Géographie"
      assert_select "a#subject_svt .bg-brand-soft.size-14 img[src*='subjects/svt']"
      assert_select "a#subject_invite[target=_blank][rel~=noopener][href^='https://wa.me/?text=']", text: tl("subjects.invite")
      assert_select "a#subject_invite[aria-label=?]", tl("invite_teacher.action_label")
    end
    assert_no_match(/subject_francais|subject_philosophie|Paiement/, response.body)
  end

  test "no published course at the student's level: the grid is only « Inviter », with its empty sentence" do
    sign_in_as create_student(classroom: create_classroom(level: create_level))

    get student_home_path

    assert_select "nav#student_subjects li", 1
    assert_select "nav#student_subjects a#subject_invite"
    assert_select "nav#student_subjects", text: including(tl("subjects.empty"))
  end

  test "the sheets to review are no longer listed on the home (Ma classe carries them)" do
    complete(assign_exercise("Fait", due_on: Date.current + 1))
    create_gap(student: @student, essential: @essential)
    create_gap(student: @student, essential: create_essential(course: @course, name: "Autre"))
    sign_in_as @student

    get student_home_path

    assert_select "#student_home_gaps, #student_home_exercises, #student_home_daily", 0
    assert_select "#{CARD}[data-state=review]"
    assert_select "#student_home a[href*='/essentials/']", 1
  end

  test "the history is a lazy frame; its frame alone lists the last sessions by day, a note and the way to Mon historique" do
    exercise = create_exercise(essential: @essential, title: "Méiose")
    session = complete(exercise, score: 90)
    sign_in_as @student

    get student_home_path

    assert_select "section#student_history h2", text: tl("history.title")
    assert_select "turbo-frame#student_home_recent_activity[loading=lazy][src='#{student_home_path}']"
    assert_no_match "Méiose", css_select("#student_history").text

    get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }

    assert_response :success
    assert_select "turbo-frame#student_home_recent_activity[target=_top]" do
      assert_select "h3", text: tl("history.today")
      assert_select "a[href='#{exercise_session_result_path(session.public_id)}']", text: including("Méiose")
      assert_select "a[href='#{exercise_session_result_path(session.public_id)}'] img[src*='subjects/svt'][alt='']", 1
      assert_select "*", text: including(I18n.t("assessment.badges.grade", grade: 18))
      assert_select "a", text: tl("history.more"), count: 0
    end
  end

  test "the history shows 3 lines by day, then « Voir plus » to Mon historique; yesterday has its own title" do
    exercise = create_exercise(essential: @essential, title: "Méiose")
    3.times { |index| create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 90, completed_at: (index + 1).hours.ago) }
    create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 90, completed_at: 1.day.ago - 1.hour)
    sign_in_as @student

    get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }

    assert_select "turbo-frame#student_home_recent_activity" do
      assert_select "li", 3
      assert_select "h3", text: tl("history.today")
      assert_select "h3", text: tl("history.yesterday"), count: 0
      assert_select "a.ui-button-secondary[href=?]", student_archive_path, text: tl("history.more")
    end
  end

  test "a grade of 14/20 or more is green, a lower one in ink, never red; under 10/20, « Refaire » starts the exercise again" do
    exercise = create_exercise(essential: @essential, title: "Méiose")
    [ 70, 65, 20, 68 ].each_with_index { |score, index| complete(exercise, score:).update!(completed_at: (index + 1).minutes.ago) }
    sign_in_as @student

    get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }

    grades = css_select("turbo-frame#student_home_recent_activity li [data-grade]")
    assert_equal [ "14/20", "13/20", "4/20" ], grades.map { it.text.squish }
    assert_equal [ true, false, false ], grades.map { it["class"].split.include?("text-success") }
    assert_select "turbo-frame#student_home_recent_activity [class*=error], turbo-frame#student_home_recent_activity [class*=warning]", 0
    assert_select "turbo-frame#student_home_recent_activity form[action=?] button.ui-button-secondary", exercise_sessions_path(exercise.public_id),
                  text: tl("history.redo"), count: 1
  end

  test "no completed session: the empty history, without « Voir plus »" do
    sign_in_as @student

    get student_home_path, headers: { "Turbo-Frame" => "student_home_recent_activity" }

    assert_select "turbo-frame#student_home_recent_activity", text: including(tl("history.empty"))
    assert_select "turbo-frame#student_home_recent_activity a, turbo-frame#student_home_recent_activity button", 0
  end

  test "the card has a title, and its section is named by it" do
    assign_exercise("Méiose", due_on: Date.current + 1)
    sign_in_as @student

    get student_home_path

    assert_select "#{CARD}[aria-labelledby=student_next_step_title]"
    assert_select "#student_next_step_title", 1
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
    assert_select "#student_next_step[data-state=no_classroom]", text: including(tl("no_classroom.title")) do
      assert_select "a[href='#{new_student_classroom_choice_path}']", text: tl("no_classroom.no_code")
    end
    assert_equal [ "Choisis ta classe", "Je n'ai pas de code" ], [ tl("no_classroom.title"), tl("no_classroom.no_code") ]
    assert_select "#student_subjects, #student_history, turbo-frame#student_home_recent_activity", 0
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

    assert_equal %w[student_next_step student_subjects student_home_announcements student_history],
                 css_select("#student_home > [id]").map { it["id"] }
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

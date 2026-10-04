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

  # ComponentsHelper::BUTTON_VARIANTS, as CSS classes: primary = bg-ink text-white, secondary = border-line bg-white.
  PRIMARY = "bg-ink.text-white".freeze
  SECONDARY = "border-line.bg-white".freeze

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
end

require "application_system_test_case"

# Lot E, PRD §5 (V1 gate): the whole teaching loop on a blank base, through the real buttons only — no open_in_modal,
# no stand-in controller, no factory. The team accepts the bootstrap invitation, builds the referential, a DRENA and a
# public lycée by import (6 « Tle D » classrooms generated), then writes and publishes a course, a sheet and an exercise;
# the teacher signs up with the school code the team read on the school page, declares a classroom and assigns the
# exercise; the student joins by the code, plays the exercise on a phone and wins « Diamant »; the teacher issues a
# recovery code and reads the result. Every write is wrapped in assert_no_page_reload.
class BouclePedagogiqueTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  # The import job writes the school and its classrooms before the request returns: seconds, on a loaded machine.
  IMPORT_WAIT = 20
  # The first modal of the run renders the course form and its rich text editor on a cold server: more than the
  # 2 s Capybara waits by default under the loaded suite (2 vCPU in CI, run 37017565081 of 2026-10-02).
  MODAL_WAIT = 10
  TEAM_CONTACT = "0100000001".freeze
  TEACHER_CONTACT = "0501020304".freeze
  STUDENT_CONTACT = "0701020304".freeze
  SCHOOL = "Lycée Classique d'Abidjan".freeze
  COURSE = "Génétique et évolution".freeze
  ESSENTIAL = "La méiose".freeze
  EXERCISE = "Méiose et chromosomes".freeze
  # [statement, type, [[answer, correct], …]] — the student picks the correct answer of each.
  QUESTIONS = [
    [ "La méiose produit quatre cellules filles.", "true_false", [ [ "Vrai", true ], [ "Faux", false ] ] ],
    [ "Combien de chromosomes compte une cellule humaine ?", "single_choice", [ [ "23", false ], [ "46", true ], [ "92", false ] ] ]
  ].freeze

  setup do
    # The server thread performs each job the moment it is enqueued, as the inline adapter would.
    queue_adapter.perform_enqueued_jobs = true
  end

  def t(key, **) = I18n.t(key, **)

  test "a blank base, then the whole loop: team, teacher, student, and the teacher reads the result" do
    assert_equal 0, Orm::User.count, "la base de départ n'est pas vierge"

    using_session(:team) { team_builds_the_referential_and_the_school }
    using_session(:team) { team_publishes_a_course_a_sheet_and_an_exercise }
    code = using_session(:teacher) { teacher_signs_up_and_assigns_the_exercise }
    session = using_session(:student) { with_mobile_viewport { student_joins_and_wins_the_diamond(code) } }
    using_session(:teacher) { teacher_issues_a_recovery_code_and_reads_the_result(session) }
  end

  private

  # ---------------------------------------------------------------------------------------------------------------------
  # Team

  def team_builds_the_referential_and_the_school
    accept_bootstrap_invitation

    click_referential(levels_path)
    assert_no_page_reload do
      click_on t("teams.levels.index.new")
      within "turbo-frame#modal dialog[open]" do
        fill_in "level[name]", with: "Tle"
        fill_in "level[position]", with: "7"
        choose t("teams.levels.cycles.second")
        click_on t("teams.levels.new.submit")
      end
      assert_toast t("teams.levels.create.created", name: "Tle")
      assert_selector "#level_tle", text: "Tle"
    end

    click_referential(series_index_path)
    assert_no_page_reload do
      click_on t("teams.series.index.new")
      within "turbo-frame#modal dialog[open]" do
        fill_in "series[name]", with: "D"
        click_on t("teams.series.new.submit")
      end
      assert_toast t("teams.series.create.created", name: "D")
      assert_selector "#series tr#series_d", text: "D"

      find("#level_series_tle_d button[aria-pressed=false]").click
      assert_toast t("teams.level_series.create.done", level: "Tle", series: "D")
      assert_selector "#level_series_tle_d button[aria-pressed=true]"
    end

    click_referential(materials_path)
    assert_no_page_reload do
      click_on t("teams.materials.index.new")
      within "turbo-frame#modal dialog[open]" do
        fill_in "material[name]", with: "SVT"
        fill_in "material[shortname]", with: "SVT"
        choose t("materials.categories.science")
        click_on t("teams.materials.new.submit")
      end
      assert_toast t("teams.materials.create.done", name: "SVT")
      assert_selector "#material_svt", text: "SVT"
    end

    click_referential(drenas_path)
    assert_no_page_reload do
      click_on t("teams.drenas.index.new")
      within "turbo-frame#modal dialog[open]" do
        fill_in "drena[name]", with: "Abidjan 1"
        click_on t("teams.drenas.new.submit")
      end
      assert_toast "DRENA « Abidjan 1 » créée."
      assert_selector "#drenas tr", text: /Abidjan 1\s+drena-abidjan-1/
    end

    team_sets_the_classroom_plan
    import_the_lycee
  end

  # D1 (owner, 2026-09-28): linking D to Tle filled its barème line, 6 public and 3 private, without any entry by hand.
  def team_sets_the_classroom_plan
    click_referential(classroom_plan_path)
    within("#classroom_plan_line_tle_d") { assert_text(/Tle\s+D\s+6\s+3/) }
    assert_no_selector "[data-plan=undefined]"
    within("#classroom_plan_total_public_both") { assert_text "6" }
  end

  # The only seed of production (ADR-0034, ADR-0038): its link is printed once, as the operator reads it.
  def accept_bootstrap_invitation
    output, = capture_io do
      with_env("TEAM_BOOTSTRAP_CONTACT" => TEAM_CONTACT) { load Rails.root.join("db/seeds/identity.rb") }
    end
    link = output[%r{/invitations/\S+}]
    assert link, "le seed n'a pas affiché de lien d'invitation : #{output}"

    visit link
    fill_in "invitation[last_name]", with: "Koné"
    fill_in "invitation[first_name]", with: "Awa"
    choose t("genders.female")
    fill_in "invitation[pin]", with: "4821"
    fill_in "invitation[pin_confirmation]", with: "4821"
    click_on "Créer mon compte"

    assert_selector "#session-form", wait: SIGN_IN_WAIT
    fill_in "session[contact]", with: TEAM_CONTACT
    fill_in "session[pin]", with: "4821"
    click_on t("identity.sessions.new.submit")

    secret = find("#second-factor-secret", wait: SIGN_IN_WAIT).text.delete(" ")
    # The code leaves by itself at the sixth digit; the codes go on once they are kept (UDR-0054 §3.6, §3.7).
    fill_in "second_factor[code]", with: ROTP::TOTP.new(secret).now
    check t("identity.second_factor_enrollments.backup_codes.kept"), wait: SIGN_IN_WAIT
    click_on t("identity.second_factor_enrollments.backup_codes.continue")

    assert_selector "main#main", wait: SIGN_IN_WAIT
    assert_current_path team_home_path
  end

  # A public lycée in the old application's format, enveloped (ADR-0039): Tle D gets the 6 classrooms of the barème, and
  # nothing else exists in the referential.
  def import_the_lycee
    file = json_file("ecoles", {
      "format" => "lnclass.schools", "version" => Entities::Catalog::ImportKind::VERSION, "drena" => "drena-abidjan-1",
      "schools" => [ { "name" => SCHOOL, "schoolsigle" => "LCA", "schoolstatus" => "active", "schooltype" => "public" } ]
    })

    navigate_to team_home_path
    within("#team_home_shortcuts") { click_on t("teams.homes.shortcuts.imports") }
    assert_no_page_reload do
      click_on t("teams.imports.index.new")
      within("#new-import-menu") { click_on t("import_kinds.schools") }
      within "turbo-frame#modal dialog[open]" do
        attach_file "import[files][]", file.path
        click_on t("teams.imports.new.submit")
      end

      using_wait_time(IMPORT_WAIT) { assert_toast t("teams.imports.create.started") }
      within "turbo-frame#modal dialog[open] turbo-frame#import_status" do
        assert_text t("teams.imports.statuses.completed")
        assert_selector "#import_counter_imported", text: "1"
        assert_selector "#import_counter_errors", text: "0"
        assert_text "Classes générées : 6"
        assert_no_text "sautés"
      end
      within("turbo-frame#modal dialog[open]") { click_on t("teams.imports.create.close") }
      assert_no_selector "turbo-frame#modal dialog[open]"
    end

    navigate_to schools_path
    find("#schools_list a", text: SCHOOL).click
    assert_selector "#school_header h1", text: SCHOOL
    (1..6).each { |n| assert_selector "[id^=classroom_]", text: "Tle D #{n}" }
    assert_no_text "Tle D 7"
    assert_equal (1..6).map { "Tle D #{it}" }, Orm::Classroom.order(:name).pluck(:name)
    # ADR-0057: the team reads the school code on the school's page, and hands it to the teacher.
    @school_code = find("#school_code_value").text
  end

  def team_publishes_a_course_a_sheet_and_an_exercise
    navigate_to team_home_path
    assert_no_page_reload do
      within("#team_home_shortcuts") { click_on t("teams.homes.shortcuts.new_course") }
      within "turbo-frame#modal dialog[open]", wait: MODAL_WAIT do
        fill_in "course[name]", with: COURSE
        select "Tle", from: "course[level_slug]"
        select "D", from: "course[series_slug]"
        select "SVT", from: "course[material_slug]"
        type_rich_text find_rich_text_editor, "L'ADN porte l'information génétique."
        click_on t("teams.courses.new.submit")
      end
      assert_toast t("teams.courses.create.created", name: COURSE)
      assert_no_selector "turbo-frame#modal dialog[open]"
    end

    navigate_to courses_path
    find("#courses_list a", text: COURSE).click
    assert_selector "#course_header h1", text: COURSE
    course = Orm::Course.find_by!(name: COURSE)

    assert_no_page_reload do
      find("button[aria-controls=course-actions-menu]").click
      click_on t("catalog.content_status.actions.publish")
      assert_toast t("teams.courses.transition.published", name: COURSE)
      assert_selector "#content_status_course_#{course.slug}", text: t("catalog.content_status.published")

      find("button[aria-controls=course-actions-menu]").click
      click_on t("catalog.courses.role_actions.new_essential")
      within "turbo-frame#modal dialog[open]" do
        fill_in "essential[name]", with: ESSENTIAL
        type_rich_text find_rich_text_editor("trix-editor#essential_content"), "La méiose produit quatre cellules haploïdes."
        click_on t("teams.essentials.new.submit")
      end
      assert_toast t("teams.essentials.create.created", name: ESSENTIAL)
      assert_no_selector "turbo-frame#modal dialog[open]"
      assert_selector "#course_essentials", text: ESSENTIAL
    end

    find("#course_essentials a", text: ESSENTIAL).click
    assert_selector "#essential_header h1", text: ESSENTIAL
    essential = Orm::Essential.find_by!(name: ESSENTIAL)

    assert_no_page_reload do
      find("button[aria-controls=essential-actions-menu]").click
      click_on t("catalog.content_status.actions.publish")
      assert_toast t("teams.essentials.transition.published", name: ESSENTIAL)
      assert_selector "#content_status_essential_#{essential.slug}", text: t("catalog.content_status.published")

      find("button[aria-controls=essential-actions-menu]").click
      click_on t("catalog.essentials.show.new_exercise")
      within "turbo-frame#modal dialog[open]" do
        fill_in "exercise[title]", with: EXERCISE
        QUESTIONS.size.times { click_on t("teams.exercises.form.add_question") }
        QUESTIONS.each_with_index { |question, index| fill_question(index, *question) }
        click_on t("teams.exercises.new.submit")
      end
      assert_toast t("teams.exercises.create.created", title: EXERCISE)
      assert_no_selector "turbo-frame#modal dialog"
      assert_selector "#essential_exercises li", text: EXERCISE
    end

    exercise = Orm::Exercise.find_by!(title: EXERCISE)
    find("#essential_exercise_#{exercise.public_id} a", text: EXERCISE).click
    assert_selector "#exercise_header h1", text: EXERCISE
    assert_no_page_reload do
      find("button[aria-controls=exercise-actions-menu]").click
      click_on t("catalog.content_status.actions.publish")
      assert_toast t("teams.exercises.transition.published", title: EXERCISE)
      assert_selector "#content_status_exercise_#{exercise.public_id}", text: t("catalog.content_status.published")
    end
    assert_equal %w[published] * 3, [ course.reload.status, essential.reload.status, exercise.reload.status ]
  end

  # ---------------------------------------------------------------------------------------------------------------------
  # Teacher

  # → the join code of the declared classroom, as the teacher reads it on its page.
  def teacher_signs_up_and_assigns_the_exercise
    visit new_teacher_registration_path
    assert_no_page_reload do
      fill_in "teacher_registration[last_name]", with: "Yao"
      fill_in "teacher_registration[first_name]", with: "Koffi"
      choose t("genders.male")
      fill_in "teacher_registration[contact]", with: TEACHER_CONTACT
      fill_in "teacher_registration[school_code]", with: @school_code
      select "SVT", from: "teacher_registration[material_slug]"
      fill_in "teacher_registration[pin]", with: "1357"
      fill_in "teacher_registration[pin_confirmation]", with: "1357"
    end
    click_on t("identity.teacher_registrations.form.submit")
    assert_toast t("identity.teacher_registrations.create.welcome")
    assert_current_path teacher_classrooms_path

    classroom = Orm::Classroom.find_by!(name: "Tle D 1")
    assert_selector "form[id^=teaching_]", count: 6
    assert_no_page_reload do
      find("form[id='teaching_#{classroom.public_id}'] button").click
      assert_selector "form[id='teaching_#{classroom.public_id}'] button[aria-pressed=true]"
      assert_selector "#teaching_counter", text: t("classroom.teachings.counter.count", count: 1)
    end
    click_on t("classroom.teaching_selections.index.finish")
    assert_current_path teacher_home_path

    find("li[id='classroom_#{classroom.public_id}'] a").click
    assert_selector "#classroom_header h1", text: "Tle D 1"
    code = find("#classroom_join_code").text
    assert_equal classroom.join_code.upcase, code

    # ADR-0072 : un cours ne s'assigne plus ; sa page du catalogue n'offre aucune action à l'enseignant.
    navigate_to courses_path
    find("#courses_list a", text: COURSE).click
    assert_selector "#course_header h1", text: COURSE
    assert_no_button "Assigner"
    assert_no_link "Assigner"

    # The « Cours » block of the classroom page leads to the course in the classroom (UDR-0062 §3.4, memo Q18).
    navigate_to teacher_home_path
    find("li[id='classroom_#{classroom.public_id}'] a").click
    within("#classroom_courses") { click_on COURSE }
    assert_current_path classroom_course_path(classroom.public_id, Orm::Course.find_by!(name: COURSE).slug)
    assert_no_button "Assigner"
    find("#classroom_course_essentials a", text: ESSENTIAL).click
    assert_selector "h1", text: ESSENTIAL
    exercise = Orm::Exercise.find_by!(title: EXERCISE)
    assert_no_page_reload do
      within("[id='assignment_#{classroom.public_id}_Exercise_#{exercise.public_id}']") { click_on "Assigner" }
      # No session days yet: « Assigner » opens the days modal (UDR-0062 §3.4); « Plus tard » assigns without a due date.
      within("turbo-frame#modal dialog[open]") { click_on "Plus tard" }
      assert_toast "#{EXERCISE} ajouté à Tle D 1."
      within("[id='assignment_#{classroom.public_id}_Exercise_#{exercise.public_id}']") { assert_text "Assigné" }
    end
    code
  end

  def teacher_issues_a_recovery_code_and_reads_the_result(session)
    classroom = Orm::Classroom.find_by!(name: "Tle D 1")
    student = Orm::User.find_by!(contact: STUDENT_CONTACT)
    navigate_to teacher_home_path
    find("li[id='classroom_#{classroom.public_id}'] a").click

    within("[id='student_#{student.public_id}']") do
      assert_text "Aya Kouassi"
      assert_text "100 %"
    end
    assert_no_page_reload do
      within("[id='student_#{student.public_id}']") { click_on t("classroom.classrooms.roster.issue_code") }
      assert_toast t("identity.pin_recovery_codes.create.issued")
      within "turbo-frame#modal dialog#pin-recovery-code-modal[open]" do
        assert_text "Aya Kouassi"
        assert_match(/\A\d{4} \d{4}\z/, find("#pin-recovery-code").text)
        click_on t("identity.pin_recovery_codes.code.close")
      end
      assert_no_selector "turbo-frame#modal dialog[open]"
    end

    # The last score in the roster leads to the detailed result (decision of the porteur, 2026-09-27). The blocks of
    # Lot E push the roster to the foot of the page, under the toast of the code just issued: it leaves after 5 s.
    assert_no_selector "[data-controller=toast]", wait: 10
    within("[id='student_#{student.public_id}']") { click_on t("classroom.classrooms.roster.see_result") }
    assert_current_path exercise_session_result_path(session.public_id)
    assert_text t("assessment.session_results.show.student", name: "Aya Kouassi")
    assert_text "20/20"
    assert_text "100 %"
    assert_text t("assessment.session_results.show.review_hint_reveal")
    assert_selector "#session_review li[id^=question_review_]", count: QUESTIONS.size
    assert_selector "#session_review [data-correct]", count: QUESTIONS.size
    QUESTIONS.each do |_, _, answers|
      correct = answers.find { |(_, is_correct)| is_correct }.first
      assert_selector "#session_review [data-correct]", text: correct
    end
    assert_no_button t("assessment.session_results.show.restart")
  end

  # ---------------------------------------------------------------------------------------------------------------------
  # Student, on a phone

  # → the finished session, whose result the teacher opens.
  def student_joins_and_wins_the_diamond(code)
    visit join_classroom_path(code)
    assert_selector "#classroom-preview", text: "Tle D 1 — #{SCHOOL}"
    assert_no_page_reload do
      fill_in "join[last_name]", with: "Kouassi"
      fill_in "join[first_name]", with: "Aya"
      choose t("genders.female")
      fill_in "join[contact]", with: STUDENT_CONTACT
      fill_in "join[pin]", with: "2468"
      fill_in "join[pin_confirmation]", with: "2468"
    end
    click_on t("classroom.joins.signup_form.submit")
    assert_toast t("classroom.joins.create.welcome")
    assert_current_path student_home_path

    assert_selector "#student_home_classroom", text: code
    assert_equal code.upcase, code
    within("#student_home_exercises li", text: EXERCISE) { click_on t("classroom.student_homes.assigned_exercise.start") }
    assert_current_path %r{\A/sessions/[^/]+\z}
    assert_selector "h1", text: EXERCISE

    assert_no_page_reload do
      QUESTIONS.each_with_index do |(statement, _, answers), index|
        assert_selector "#question-card", text: statement
        choose answers.find { |(_, correct)| correct }.first
        click_on t("assessment.exercise_sessions.question_card.submit")
        assert_selector "#feedback-card", text: t("assessment.exercise_sessions.feedback_card.verdict.success")
        click_on t("assessment.exercise_sessions.feedback_card.next") if index < QUESTIONS.size - 1
      end
      assert_selector "#progress_bar progress[value='100']"
    end
    session = Orm::ExerciseSession.sole
    assert_equal [ "completed", 100 ], session.reload.values_at(:status, :score_percent)

    click_on t("assessment.exercise_sessions.feedback_card.result")
    assert_current_path exercise_session_result_path(session.public_id)
    assert_selector "h1", text: t("assessment.session_results.show.headline.success")
    assert_text "20/20"
    assert_selector "#session_badge[aria-label='#{t('assessment.session_results.badge.label', level: 'Diamant')}']"
    assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    session
  end

  # ---------------------------------------------------------------------------------------------------------------------
  # Helpers

  # A destination of the shell navigation, or a card of the team home: the first visible link to that path.
  def navigate_to(path)
    first("a[href='#{path}']", visible: true).click
    assert_current_path path
  end

  # UDR-0068 §3.4 : le Référentiel a sa page, atteinte par la carte « Configuration » de la barre latérale.
  def click_referential(path)
    navigate_to teams_referential_path
    within("#team_referential") { find("a[href='#{path}']").click }
    assert_current_path path
  end

  def type_rich_text(editor, text)
    editor.click
    editor.send_keys(text)
  end

  def questions = all("#exercise-questions > [data-teams--nested-form-target=list] > fieldset")

  def fill_question(index, content, type, pairs)
    within(questions[index]) do
      find("textarea[name$='[content]']").fill_in with: content
      find("select[name$='[question_type]']").select t("teams.exercises.question_types.#{type}")
      (pairs.size - all("[data-nested-answer]").size).times { click_on t("teams.exercises.question_fields.add_answer") }
      pairs.each_with_index do |(text, correct), rank|
        within(all("[data-nested-answer]")[rank]) do
          find("input[type=text]").fill_in with: text
          find("input[type=checkbox]").set(correct)
        end
      end
    end
  end

  def json_file(name, document)
    Tempfile.create([ name, ".json" ]).tap do |file|
      file.write(document.to_json)
      file.close
    end
  end

  def with_env(values)
    previous = values.keys.to_h { [ it, ENV[it] ] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end

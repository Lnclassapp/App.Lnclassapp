require "application_system_test_case"

# Lot E, PRD §5 (V1 gate): the whole teaching loop on a blank base, through the real buttons only — no open_in_modal,
# no stand-in controller, no factory. The team accepts the bootstrap invitation, builds the referential, a DRENA and a
# public lycée by import (6 « Tle D » classrooms generated), then imports a whole lesson (ADR-0113) and publishes it;
# the teacher signs up by the DRENA, then the school (ADR-0083), with a full name, declares a classroom and assigns the
# exercise; the student joins by the classroom link, plays the exercise on a phone and wins « Diamant »; the teacher issues a
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
    using_session(:team) { team_imports_and_publishes_a_lesson }
    link = using_session(:teacher) { teacher_signs_up_and_assigns_the_exercise }
    session = using_session(:student) { with_mobile_viewport { student_joins_and_wins_the_diamond(link) } }
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
  end

  # ADR-0113 §4.6 : plus d'écran pour écrire une notion ni un exercice ; l'équipe importe la leçon complète (format 2 : un
  # exercice par notion, quatre sur toute la leçon), tout arrive en brouillon, puis « Tout publier ».
  def team_imports_and_publishes_a_lesson
    file = json_file("lecon", lesson_document)

    navigate_to team_home_path
    within("#team_home_shortcuts") { click_on t("teams.homes.shortcuts.imports") }
    assert_no_page_reload do
      click_on t("teams.imports.index.new")
      within("#new-import-menu") { click_on t("import_kinds.course_tree") }
      within "turbo-frame#modal dialog[open]", wait: MODAL_WAIT do
        attach_file "import[files][]", file.path
        click_on t("teams.imports.new.submit")
      end

      using_wait_time(IMPORT_WAIT) { assert_toast t("teams.imports.create.started") }
      within "turbo-frame#modal dialog[open] turbo-frame#import_status" do
        assert_text t("teams.imports.statuses.completed")
        assert_selector "#import_counter_imported", text: "1"
        assert_selector "#import_counter_errors", text: "0"
      end
      within("turbo-frame#modal dialog[open]") { click_on t("teams.imports.create.close") }
      assert_no_selector "turbo-frame#modal dialog[open]"
    end
    course = Orm::Course.find_by!(name: COURSE)
    assert_equal [ "draft", 1, 5 ], [ course.status, course.essentials.count, Orm::Exercise.where(course_id: course.id).count ]

    navigate_to courses_path
    find("#courses_list a", text: COURSE).click
    assert_selector "#course_header h1", text: COURSE

    assert_no_page_reload do
      find("button[aria-controls=course-actions-menu]").click
      click_on t("catalog.content_status.actions.publish_all")
      assert_toast t("teams.publish_cascade.done.course", name: COURSE, essentials: t("teams.publish_cascade.essentials", count: 1),
                                                          exercises: t("teams.publish_cascade.exercises", count: 5))
    end
    assert_equal %w[published], [ course.reload.status ]
    assert_equal [ "published" ], Orm::Exercise.where(course_id: course.id).distinct.pluck(:status)
  end

  # Format 2 de l'import `lnclass.course-tree` : la leçon, sa notion et son exercice (QUESTIONS), puis les quatre exercices de
  # toute la leçon.
  def lesson_document
    questions = QUESTIONS.map do |statement, type, answers|
      { "content" => statement, "question_type" => type,
        "answers" => answers.map { |content, correct| { "content" => content, "correct" => correct } } }
    end
    {
      "format" => "lnclass.course-tree", "version" => 2,
      "courses" => [ {
        "name" => COURSE, "subtitle" => "Leçon 1", "content" => "<p>L'ADN porte l'information génétique.</p>",
        "level_name" => "Tle", "series_name" => "D", "material_name" => "SVT",
        "essentials" => [ { "name" => ESSENTIAL, "subtitle" => "Quatre cellules", "content" => "<p>La méiose produit quatre cellules haploïdes.</p>",
                            "exercises" => [ { "title" => EXERCISE, "statement" => "Lis le sujet.", "exercise_type" => "fixation", "questions" => questions } ] } ],
        "exercises" => Array.new(4) do |index|
          { "title" => "Bilan #{index + 1}", "statement" => "Sur toute la leçon.", "exercise_type" => "evaluation", "questions" => questions }
        end
      } ]
    }
  end

  # ---------------------------------------------------------------------------------------------------------------------
  # Teacher

  # → the link of the declared classroom, as the teacher copies it on its page (ADR-0085 §4.1).
  def teacher_signs_up_and_assigns_the_exercise
    visit new_teacher_registration_path
    assert_no_page_reload do
      select "Abidjan 1", from: "teacher_registration[drena_public_id]"
      select SCHOOL, from: "teacher_registration[school_public_id]"
      select "SVT", from: "teacher_registration[material_slug]"
      fill_in "teacher_registration[last_name]", with: "YAO"
      fill_in "teacher_registration[first_name]", with: "Koffi"
      choose t("identity.teacher_registrations.form.genders.male")
      fill_in "teacher_registration[contact]", with: TEACHER_CONTACT
      fill_in "teacher_registration[pin]", with: "1357"
      fill_in "teacher_registration[pin_confirmation]", with: "1357"
    end
    click_on t("identity.teacher_registrations.form.submit")
    assert_toast t("identity.teacher_registrations.create.welcome")
    assert_current_path teacher_home_path # UDR enseignant §3.13 : l'accueil demande les classes
    visit teacher_classrooms_path
    assert_equal [ "YAO", "Koffi" ], Orm::User.where(contact: TEACHER_CONTACT).pick(:last_name, :first_name)

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
    link = find("#classroom_link [data-clipboard-text-value^='http']")["data-clipboard-text-value"]
    assert_equal join_classroom_url(classroom.reload.link_token, host: URI(link).host, port: URI(link).port), link

    # ADR-0072 : un cours ne s'assigne plus ; sa page n'offre « Assigner » que sous un exercice de « Prépare interros » (UDR-0139).
    navigate_to courses_path
    find("#courses_list a", text: COURSE).click
    assert_selector "#course_header h1", text: COURSE
    assert_no_selector "#course_header", text: "Assigner"
    assert_selector "#prepare-interros"

    # La notion n'a plus de page (ADR-0113) : « Prépare interros » de la leçon porte l'exercice, et chaque classe y a son « Assigner ».
    assert_selector "#notion-#{Orm::Essential.find_by!(name: ESSENTIAL).slug}", text: EXERCISE
    exercise = Orm::Exercise.find_by!(title: EXERCISE)
    assert_no_page_reload do
      within("[id='assignment_#{classroom.public_id}_Exercise_#{exercise.public_id}']") { click_on "Assigner" }
      # No session days yet: « Assigner » opens the days modal (UDR-0062 §3.4), which asks for a day (no « Plus tard »).
      within("turbo-frame#modal dialog[open]") do
        find("label", text: "Lun.").click
        click_on "Assigner"
      end
      assert_toast "#{EXERCISE} ajouté à Tle D 1, à rendre"
      within("[id='assignment_#{classroom.public_id}_Exercise_#{exercise.public_id}']") { assert_text "Assigné" }
    end
    link
  end

  def teacher_issues_a_recovery_code_and_reads_the_result(session)
    classroom = Orm::Classroom.find_by!(name: "Tle D 1")
    student = Orm::User.find_by!(contact: STUDENT_CONTACT)
    navigate_to teacher_home_path
    find("li[id='classroom_#{classroom.public_id}'] a").click

    within("[id='student_#{student.public_id}']") do
      assert_text "Aya Kouassi"
      # Maquette 10 : la ligne dit ses exercices faits et le badge de classe de l'élève (un 100 % sans faute : Diamant, 20/20).
      assert_text "1 fait sur 1"
      assert_text "Diamant · 20/20"
    end
    assert_no_page_reload do
      issue_recovery_code_from_roster("[id='student_#{student.public_id}']")
      assert_toast t("identity.pin_recovery_codes.create.issued")
      within "turbo-frame#modal dialog#pin-recovery-code-modal[open]" do
        assert_text "Aya Kouassi"
        assert_match(/\A\d{4} \d{4}\z/, find("#pin-recovery-code").text)
        click_on t("identity.pin_recovery_codes.code.close")
      end
      assert_no_selector "turbo-frame#modal dialog[open]"
    end

    # The toast of the code just issued leaves after 5 s.
    assert_no_selector "[data-controller=toast]", wait: 10
    # The code was issued from the student's file (rapports-de-classe, memo Q4): the file leads to the detailed result of the
    # best session (the roster row no longer carries a score at 390 px, maquette 10).
    assert_selector "#student_file_summary", text: "Diamant"
    within("#student_file_assignments li", text: EXERCISE) do
      assert_text "20/20"
      click_on t("classroom.classroom_students.assignments.best_session")
    end
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
  def student_joins_and_wins_the_diamond(link)
    visit URI(link).path
    assert_selector "#signup-classroom-recap", text: /Tle D 1.*#{SCHOOL}/m
    assert_no_page_reload do
      fill_in "student_registration[last_name]", with: "Kouassi"
      fill_in "student_registration[first_name]", with: "Aya"
      choose t("genders.female")
      fill_in "student_registration[contact]", with: STUDENT_CONTACT
      # Step 2 moves on to the secret code (step 3) a second after the last key.
      fill_in "student_registration[pin]", with: "2468"
      fill_in "student_registration[pin_confirmation]", with: "2468"
    end
    click_on t("classroom.student_registrations.form.submit")
    assert_toast t("classroom.student_registrations.create.welcome")
    assert_current_path student_home_path

    assert_selector "#student_next_step", text: /Tle D 1/i
    within("#student_next_step", text: EXERCISE) { click_on t("classroom.student_homes.next_step.due.start") }
    assert_current_path %r{\A/sessions/[^/]+\z}
    assert_selector "a", text: EXERCISE

    assert_selector "#copy-form"
    QUESTIONS.each_with_index do |(statement, _, answers), index|
      within("#question-#{index + 1}") do
        assert_text statement
        choose answers.find { |(_, correct)| correct }.first
      end
    end
    click_on t("assessment.exercise_sessions.show.submit")
    session = Orm::ExerciseSession.sole
    assert_current_path exercise_session_result_path(session.public_id)
    assert_equal [ "completed", 100 ], session.reload.values_at(:status, :score_percent)
    assert_selector "h1", text: t("assessment.session_results.show.headline.very_good")
    assert_text "20/20"
    assert_selector "#session_badge[aria-label='#{t('assessment.session_results.badge.label', level: 'Diamant')}']"
    assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    session
  end

  # ---------------------------------------------------------------------------------------------------------------------
  # Helpers

  # A destination of the shell navigation, or a card of the team home: the first visible link to that path. Turbo
  # pushes the address when the visit starts, and shows its cached copy of a page seen before until the answer comes:
  # a click on the copy, swapped for the page mid-click, is lost. The next step waits for the page itself.
  def navigate_to(path)
    first("a[href='#{path}']", visible: true).click
    assert_current_path path
    assert_no_selector "html[data-turbo-preview]"
  end

  # UDR-0068 §3.4 : le Référentiel a sa page, atteinte par la carte « Configuration » de la barre latérale.
  def click_referential(path)
    navigate_to teams_referential_path
    within("#team_referential") { find("a[href='#{path}']").click }
    assert_current_path path
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

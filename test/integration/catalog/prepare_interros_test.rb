require "test_helper"

# UDR feuilles-prepare-interros-et-devoirs §3, PRD prepare-interros-cahier (CA-1, 2, 6, 7, 11) : les feuilles « Prépare interros » et
# « Prépare devoirs » de la page d'une leçon, lues par chaque rôle.
class Catalog::PrepareInterrosTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Thalès")
    @notions = Array.new(4) do |index|
      create_essential(course: @course, name: "Notion #{index + 1}", position: index + 1, sheet: { "remember" => "Retiens #{index + 1}." })
    end
    @by_notion = @notions.map { |essential| create_exercise(essential:, title: "Exercice #{essential.name}", hint: "Indice de #{essential.name}") }
    @wide = Array.new(2) { |index| create_lesson_wide_exercise(course: @course, title: "Toute la leçon #{index + 1}") }
    @classroom = create_classroom(level: @course.level, series: @course.series)
    @student = create_student(classroom: @classroom)
    @teacher = create_teacher(classrooms: [ @classroom ])
  end

  def sheet(index) = "#prepare-interros .ps-sheet:nth-of-type(#{index})"
  def frame(exercise) = "turbo-frame#sheet-exercise-#{exercise.public_id}"
  def including(text) = /#{Regexp.escape(text)}/

  # CA-1
  test "a student reads one sheet per notion, then « Toute la leçon », with the header, the title, « À retenir » and the exercise" do
    sign_in_as @student

    get course_path(@course.slug)

    assert_response :success
    assert_select "#prepare-interros .ps-sheet", 5
    assert_select "#prepare-interros .ps-sheet[data-controller=prepare-sheet][data-prepare-sheet-owner-value=?]", @student.id.to_s, 5
    assert_select "#prepare-interros .ps-exercise-head .ps-status", text: /Brouillon|Publié/, count: 0
    assert_select "#notion-#{@notions.first.slug}.ps-sheet" do
      assert_select ".ps-header", text: including("PRÉPARE INTERROS")
      assert_select ".ps-header", text: including(@course.material.name.upcase)
      assert_select ".ps-header", text: including("Lnclass · Thalès")
      assert_select ".ps-header", text: including("Classe de #{@course.level.name} · Notion 1 / 5")
      # UDR-0149 §3 (ajout du 2026-10-31) : le titre est numéroté, le nom de la notion passe en sous-titre.
      assert_select ".ps-title", text: "Prépare interros n°1"
      assert_select ".ps-title-block .ps-subject", text: "Notion 1"
      assert_select "#sheet-progress-notion-#{@notions.first.slug}.ps-progress", text: "0 / 1 exercice réussi"
      assert_select ".ps-remember", text: "À retenir : Retiens 1."
      assert_select ".ps-exercise-head", text: including("Exercice 1")
      assert_select ".ps-footer", text: including("Lnclass · Prépare interros · Notion 1")
      assert_select ".ps-footer button", text: "Recommencer cette notion"
    end
    assert_select "#toute-la-lecon.ps-sheet" do
      assert_select ".ps-title", text: "Prépare interros n°5"
      assert_select ".ps-title-block .ps-subject", text: "Toute la leçon"
      assert_select ".ps-remember", 0
      assert_select ".ps-progress", text: "0 / 2 exercice réussi"
      assert_select ".ps-exercise", 2
    end
    assert_select "#prepare-interros a[href='#{exercise_path(@by_notion.first.public_id)}']", 0
  end

  test "each question carries its tag and label, the QCM its lettered propositions, and the form targets the sheet check" do
    exercise = @by_notion.first
    create_kind_question(exercise:, question_type: "fill_blank", content: "AM/AB = AN/___", answers: [ "AC" ])
    create_kind_question(exercise:, question_type: "numeric", content: "Calcule MN.", answers: [ "6" ]).update!(unit: "cm")
    vf = exercise.questions.create!(position: 9, content: "Le triangle est rectangle.", question_type: "true_false")
    [ [ 1, "Vrai", true ], [ 2, "Faux", false ] ].each { |position, content, correct| vf.answers.create!(position:, content:, correct:) }
    sign_in_as @student

    get course_path(@course.slug)

    assert_select frame(exercise) do
      assert_select "form[action='#{exercise_sheet_check_path(exercise.public_id)}'][method=post]"
      assert_select ".ps-tag", text: "QCM"
      assert_select ".ps-tag", text: "Complète"
      assert_select ".ps-tag", text: "Calcul"
      assert_select ".ps-tag", text: "Vrai ou faux"
      assert_select ".ps-question-label", text: including("a. ")
      assert_select ".ps-question-label", text: including("AM/AB = AN/…")
      assert_select "[role=radiogroup] button.ps-choice[role=radio][aria-checked=false]", 8
      assert_select ".ps-choice-letter", text: "A."
      assert_select ".ps-choices-vf button.ps-choice-vf", 2
      assert_select "input.ps-input[name$='[response_text]'][aria-label]", 2
      assert_select ".ps-numeric", text: including("cm")
      assert_select "button.ps-btn--primary", text: "Vérifier ma réponse"
    end
  end

  # CA-2
  test "a student reads the sheets of the homework subjects under « Prépare devoirs », with « Notions mobilisées »" do
    subject = create_subject(course: @course, title: "Sujet 1 · Calculer, démontrer, conclure", notions: "Thalès et sa réciproque")
    create_exercise(subject:, course: @course, title: "Devoir 1", position: 40)
    create_exercise(subject:, course: @course, title: "Devoir 2", position: 41)
    sign_in_as @student

    get course_path(@course.slug)

    assert_select "#prepare-devoirs h2", text: "Prépare devoirs"
    assert_select "#prepare-devoirs .ps-sheet", 1
    assert_select "#prepare-devoirs .ps-header", text: including("PRÉPARE DEVOIRS")
    assert_select "#prepare-devoirs .ps-header", text: including("Sujet 1 / 1")
    assert_select "#prepare-devoirs .ps-title", text: "Prépare devoirs n°1"
    assert_select "#prepare-devoirs .ps-title-block .ps-subject", text: "Sujet 1 · Calculer, démontrer, conclure"
    assert_select "#prepare-devoirs .ps-remember", text: "Notions mobilisées : Thalès et sa réciproque"
    assert_select "#prepare-devoirs .ps-exercise", 2
    assert_select "#prepare-devoirs .ps-footer", text: including("Lnclass · Prépare devoirs · Sujet 1")
    assert_select "#prepare-devoirs .ps-footer button", text: "Recommencer ce sujet"
  end

  test "a lesson without subject has no « Prépare devoirs » section" do
    sign_in_as @student

    get course_path(@course.slug)

    assert_select "#prepare-devoirs", 0
  end

  # CA-6
  test "the hint is in the page, hidden, behind an « Indice » button; an exercise without hint has none" do
    exercise = @by_notion.first
    @by_notion.second.update!(hint: nil)
    sign_in_as @student

    get course_path(@course.slug)

    assert_select "#{frame(exercise)} .ps-hint[hidden]", text: "Indice : Indice de Notion 1"
    assert_select "#{frame(exercise)} button.ps-btn--hint[aria-expanded=false]", text: "Indice"
    assert_select "#{frame(@by_notion.second)} .ps-hint", 0
    assert_select "#{frame(@by_notion.second)} button.ps-btn--hint", 0
  end

  test "text coming from the import is escaped, never rendered as HTML" do
    @by_notion.first.update!(hint: "<script>alert(1)</script>", statement: "<img src=x onerror=alert(2)>")
    sign_in_as @student

    get course_path(@course.slug)

    assert_select "#prepare-interros script", 0
    assert_select "#prepare-interros img[onerror]", 0
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
  end

  test "before the check, the page holds no correction: neither a good answer nor an explanation" do
    @by_notion.first.questions.first.update!(explanation: "Parce que A.")
    sign_in_as @student

    get course_path(@course.slug)

    assert_select ".ps-result", 0
    assert_select "a", text: "Voir ma correction", count: 0
    assert_select "button.ps-btn--redo[hidden]", 4 + 2
    assert_not_includes response.body, "Parce que A."
    assert_not_includes response.body, "Bonne réponse"
  end

  # CA-3 / CA-7 (rechargement)
  test "an exercise already checked by the student shows its status, « Voir ma correction » and « Refaire l'exercice », no grade" do
    exercise = create_exercise(essential: @notions.first, title: "Cinq questions", questions: 5, position: 60)
    session = create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 80)
    session.update!(correct_count: 4, question_count: 5)
    exercise.questions.each_with_index do |question, index|
      answers = question.answers.order(:position).to_a
      chosen = index == 4 ? answers.second : answers.first
      Orm::QuestionAttempt.create!(exercise_session: session, question:, correct: index != 4, selected_answer_ids: [ chosen.id ], answered_at: Time.current)
    end
    sign_in_as @student

    get course_path(@course.slug)

    assert_select frame(exercise) do
      assert_select "[data-checked=true][data-copy='#{session.public_id}']"
      assert_select ".ps-status", text: "À revoir"
      # Lot C bis : ni note ni correction sur la feuille ; la copie a sa page de résultat.
      assert_select ".ps-result", 0
      assert_select ".ps-result-grade", 0
      assert_select "a.ps-btn--redo[href=?]", exercise_session_result_path(session.public_id, return_to: "sheet"), text: "Voir ma correction"
      assert_select "button.ps-btn--redo:not([hidden])", text: "Refaire l'exercice"
      assert_select "button.ps-btn--primary[hidden]"
      assert_select "button.ps-choice[aria-checked=true]", 5
    end
    assert_select "#sheet-progress-notion-#{@notions.first.slug}", text: "0 / 2 exercice réussi"
  end

  test "an exercise whose every question is right is « Réussi » and counted in the progress" do
    session = create_exercise_session(student: @student, exercise: @by_notion.first, status: "completed", score_percent: 100)
    session.update!(correct_count: 2, question_count: 2)
    @by_notion.first.questions.each do |question|
      Orm::QuestionAttempt.create!(exercise_session: session, question:, correct: true, selected_answer_ids: [ question.answers.order(:position).first.id ], answered_at: Time.current)
    end
    sign_in_as @student

    get course_path(@course.slug)

    assert_select "#{frame(@by_notion.first)} .ps-status", text: "Réussi"
    assert_select "#sheet-progress-notion-#{@notions.first.slug}", text: "1 / 1 exercice réussi"
  end

  # CA-8 (périmètre du Lot B : l'enseignant garde ses bascules d'aujourd'hui)
  test "a teacher reads the sheets without field, check button or hint button, and keeps one assignment toggle per class" do
    sign_in_as @teacher

    get course_path(@course.slug)

    assert_response :success
    assert_select "#prepare-interros .ps-sheet", 5
    assert_select "#prepare-interros input:not([type=hidden])", 0
    assert_select "#prepare-interros .ps-input, #prepare-interros [data-ps-choice]", 0
    assert_select "#prepare-interros textarea, #prepare-interros select", 0
    assert_select "#prepare-interros button", text: "Vérifier ma réponse", count: 0
    assert_select "#prepare-interros button.ps-btn--hint", 0
    assert_select "#prepare-interros .ps-footer button", 0
    assert_select "#{frame(@by_notion.first)} #assignment_#{@classroom.public_id}_Exercise_#{@by_notion.first.public_id}"
  end

  test "the team reads the same sheets, drafts included, with neither field nor assignment toggle" do
    create_exercise(essential: @notions.first, title: "Brouillon", status: "draft", position: 90)
    sign_in_as create_team_member

    get course_path(@course.slug)

    assert_select "#prepare-interros .ps-exercise", 7
    assert_select "#prepare-interros input:not([type=hidden])", 0
    assert_select "#prepare-interros .ps-input, #prepare-interros [data-ps-choice]", 0
    assert_select "#prepare-interros [id^=assignment_]", 0
    assert_select "#toute-la-lecon", 1
    assert_select "#prepare-interros .ps-exercise-head .ps-status", text: including("Brouillon"), count: 1
    assert_select "#prepare-interros .ps-exercise-head .ps-status", text: "Publié", count: 6
    assert_select "#prepare-interros button", text: "Vérifier ma réponse", count: 0
  end

  test "a lesson without exercise says so, for a teacher too, and offers no sheet nor assignment" do
    course = create_course
    sign_in_as @teacher

    get course_path(course.slug)

    assert_response :success
    assert_select "#prepare-interros", text: including(I18n.t("catalog.courses.show.exercises_empty"))
    assert_select "#prepare-interros .ps-sheet", 0
    assert_select "#prepare-interros [id^=assignment_]", 0
  end

  test "a notion without exercise keeps its anchor and says so" do
    bare = create_essential(course: @course, name: "Sans exercice", position: 9)
    sign_in_as @student

    get course_path(@course.slug)

    assert_select "#notion-#{bare.slug}", text: including(I18n.t("catalog.courses.show.notion_without_exercise"))
  end

  # PRD §7 : « avant » = 36 (journal du chantier) ; un sujet de devoir ajoute une lecture.
  test "the lesson page reads at most 39 SQL queries for a student (4 notions x 3 exercises + 1 whole-lesson exercise)" do
    course = create_course(name: "Mesure")
    classroom = create_classroom(level: course.level, series: course.series)
    student = create_student(classroom:)
    4.times do |index|
      essential = create_essential(course:, name: "M#{index}", position: index + 1)
      3.times { create_exercise(essential:, questions: 4) }
    end
    create_lesson_wide_exercise(course:, questions: 4)
    create_exercise(subject: create_subject(course:), course:, questions: 4)
    sign_in_as student
    get course_path(course.slug)

    assert_operator count_queries { get course_path(course.slug) }, :<=, 39
  end

  private

  def count_queries
    count = 0
    ignored = /\A(BEGIN|COMMIT|SAVEPOINT|RELEASE|ROLLBACK)/
    counter = ->(*, payload) { count += 1 unless payload[:cached] || payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION" || payload[:sql].match?(ignored) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end
end

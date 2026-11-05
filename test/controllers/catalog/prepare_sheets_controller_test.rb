require "test_helper"

# sujet-avant-de-commencer, Lot A (UDR feuilles-en-cases-lues-avant-de-commencer §3) : la page d'une feuille de la leçon, en lecture
# (le sujet complet, champs désactivés) puis à remplir (la feuille d'aujourd'hui), avec les mêmes autorisations que la leçon.
class Catalog::PrepareSheetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Thalès")
    @notion = create_essential(course: @course, name: "Réciproque", position: 1, sheet: { "remember" => "Retiens." })
    @ex = create_exercise(essential: @notion, title: "Exercice notion", hint: "Relis l'énoncé.")
    @subject = create_subject(course: @course, title: "Sujet 1 · Démontrer", notions: "Thalès")
    @devoirs = Array.new(2) { |index| create_exercise(subject: @subject, course: @course, title: "Devoir #{index + 1}", position: 40 + index) }
    @classroom = create_classroom(level: @course.level, series: @course.series)
    @student = create_student(classroom: @classroom)
    @teacher = create_teacher(classrooms: [ @classroom ])
    @notion_sheet = "notion-#{@notion.slug}"
    @devoir_sheet = "sujet-#{@subject.position}"
  end

  def including(text) = /#{Regexp.escape(text)}/
  def frame(exercise) = "turbo-frame#sheet-exercise-#{exercise.public_id}"
  # sujet-comme-une-epreuve : en lecture, l'exercice est une section de l'épreuve ; le cadre n'existe que sur la feuille à remplir.
  def paper(exercise) = "section.ps-paper-exercise#sheet-exercise-#{exercise.public_id}"

  test "a student reads the whole subject: every exercise, disabled fields, and neither check button, hint, status nor script" do
    sign_in_as @student

    get course_sheet_path(@course.slug, @devoir_sheet)

    assert_response :success
    assert_select "h1.ps-paper-heading", text: /\AÉPREUVE DE /
    assert_select ".ps-paper-name", text: including("Prépare devoirs n°1")
    assert_select ".ps-paper .ps-paper-exercise", 2
    @devoirs.each { |exercise| assert_select %w[input select textarea fieldset button].map { "#{paper(exercise)} #{it}" }.join(", "), 0 }
    assert_select ".ps-sheet button.ps-btn--primary", 0
    assert_select ".ps-sheet button.ps-btn--hint", 0
    assert_select ".ps-hint", 0
    assert_select ".ps-sheet .ps-footer button", 0
    assert_select ".ps-sheet .ps-status:not([hidden])", 0
    assert_select ".ps-verdict", 0
    assert_select ".ps-sheet [data-controller~=prepare-sheet]", 0
    assert_select ".ps-sheet [data-prepare-sheet-target]", 0
    assert_select ".ps-sheet form", 0
    assert_select ".ps-remember", 0
    assert_no_match "Notions mobilisées", response.body

    # La feuille à remplir garde ses « Notions mobilisées ».
    get fill_course_sheet_path(@course.slug, @devoir_sheet)
    assert_select ".ps-remember", text: "Notions mobilisées : Thalès"
  end

  test "the QCM propositions are readable in the table, without any field" do
    sign_in_as @student

    get course_sheet_path(@course.slug, @notion_sheet)

    assert_select "#{paper(@ex)} table.ps-paper-table--mcq tbody td:nth-child(n + 3)", 8
    assert_select "#{paper(@ex)} table.ps-paper-table--mcq tbody td:nth-child(3)", text: "Proposition 1", minimum: 1
    assert_select %w[input select textarea fieldset button [role=radio] [role=checkbox] [aria-checked]].map { "#{paper(@ex)} #{it}" }.join(", "), 0
    # @ex porte un indice : la lecture ne le montre pas, ni son bouton.
    assert_select "#{paper(@ex)} button.ps-btn--hint", 0
    assert_select "#{paper(@ex)} .ps-hint", 0
    assert_no_match "Relis l", response.body
  end

  test "the page offers « Commencer l'exercice » towards the sheet to fill, and a link back to the lesson at the sheet's card" do
    sign_in_as @student

    get course_sheet_path(@course.slug, @devoir_sheet)

    assert_select "a.ps-start[href=?]", fill_course_sheet_path(@course.slug, @devoir_sheet), text: "Commencer l'exercice"
    assert_select "a[href=?]", course_path(@course.slug, anchor: @devoir_sheet), text: including("Thalès")
  end

  test "the button still says « Commencer l'exercice » once an exercise of the sheet has a finished copy" do
    create_exercise_session(student: @student, exercise: @devoirs.first, status: "completed", score_percent: 100)
    sign_in_as @student

    get course_sheet_path(@course.slug, @devoir_sheet)

    assert_select "a.ps-start", text: "Commencer l'exercice"
    assert_select "a.ps-start", text: /Continuer/, count: 0
    assert_select "#sheet-progress-#{@devoir_sheet}", 0

    # La progression se lit sur la feuille à remplir.
    get fill_course_sheet_path(@course.slug, @devoir_sheet)
    assert_select "#sheet-progress-#{@devoir_sheet}", text: "1 / 2 exercice réussi"
  end

  test "the interros sheet offers « Commencer l'exercice »" do
    sign_in_as @student

    get course_sheet_path(@course.slug, @notion_sheet)

    assert_select "h1.ps-paper-heading"
    assert_select ".ps-paper-name", text: including("Prépare interros n°1")
    assert_select "a.ps-start", text: "Commencer l'exercice"
    assert_select "a.ps-start", text: /Continuer/, count: 0
  end

  test "the sheet to fill is today's sheet: active fields, the check button, and the sheet posted with the check" do
    sign_in_as @student

    get fill_course_sheet_path(@course.slug, @devoir_sheet)

    assert_response :success
    assert_select "[data-controller=prepare-sheet]", 1
    assert_select "fieldset[disabled]", 0
    assert_select "#{frame(@devoirs.first)} button.ps-btn--primary", text: "Vérifier ma réponse"
    assert_select "#{frame(@devoirs.first)} form[action=?]", exercise_sheet_check_path(@devoirs.first.public_id) do
      assert_select "input[type=hidden][name=sheet][value=?]", @devoir_sheet
      assert_select "input[type=hidden][name=return_to][value=sheet]"
    end
    assert_select "a[href=?]", course_sheet_path(@course.slug, @devoir_sheet), text: including("Lire le sujet")
    assert_select "a.ps-start", 0
  end

  # refaire-ou-continuer (UDR §3) : `redo` ne compte que s'il désigne un exercice de la feuille.
  test "the sheet to fill carries the exercise to redo when it belongs to the sheet, and ignores any other value" do
    sign_in_as @student

    get fill_course_sheet_path(@course.slug, @devoir_sheet, redo: @devoirs.first.public_id)

    assert_select "[data-controller=prepare-sheet][data-prepare-sheet-redo-value=?]", @devoirs.first.public_id

    [ @ex.public_id, "inconnu", "" ].each do |value|
      get fill_course_sheet_path(@course.slug, @devoir_sheet, redo: value)

      assert_response :success
      assert_select "[data-prepare-sheet-redo-value]", 0
    end
    get fill_course_sheet_path(@course.slug, @devoir_sheet, redo: [ @devoirs.first.public_id ])
    assert_select "[data-prepare-sheet-redo-value]", 0
  end

  test "an unknown or withdrawn sheet sends back to the lesson with a message, never a 500" do
    sign_in_as @student

    [ course_sheet_path(@course.slug, "sujet-9"), fill_course_sheet_path(@course.slug, "sujet-9"),
      course_sheet_path(@course.slug, "n-importe-quoi") ].each do |path|
      get path

      assert_redirected_to course_path(@course.slug)
      assert_equal 303, response.status
      assert_equal "Cette feuille n'existe plus.", flash[:alert]
    end
  end

  test "an unknown course answers 404" do
    sign_in_as @student

    get course_sheet_path("introuvable", "toute-la-lecon")

    assert_response :not_found
  end

  test "a draft lesson answers 404 to a student, a lesson of another level too" do
    draft = create_course(name: "Brouillon", level: @course.level, series: @course.series, status: "draft")
    create_lesson_wide_exercise(course: draft, title: "Dans un brouillon")
    other = create_course(name: "Autre niveau", level: create_level(name: "Autre", position: 20))
    create_lesson_wide_exercise(course: other, title: "Hors niveau")
    sign_in_as @student

    get course_sheet_path(draft.slug, "toute-la-lecon")
    assert_response :not_found

    get fill_course_sheet_path(other.slug, "toute-la-lecon")
    assert_response :not_found
  end

  test "a teacher reads the subject with her assignment toggles and the send bar, but never « Commencer »" do
    sign_in_as @teacher

    get course_sheet_path(@course.slug, @devoir_sheet)

    assert_response :success
    assert_select "a.ps-start", 0
    assert_select "#{paper(@devoirs.first)} #assignment_#{@classroom.public_id}_Exercise_#{@devoirs.first.public_id}"
    assert_select "#{paper(@devoirs.first)} button[role=checkbox]"
    assert_select "#sheet-batch-bar", 1
    assert_select "#sheet-batch-bar form[action=?]", classroom_assignment_batches_path(@classroom.public_id)
    assert_select "button.ps-btn--primary", text: "Vérifier ma réponse", count: 0
  end

  test "a teacher without any classroom of this level is told so on the reading page" do
    sign_in_as create_teacher(classrooms: [ create_classroom(name: "6ème 1") ])

    get course_sheet_path(@course.slug, @devoir_sheet)

    assert_select "#assign_targets_none", text: /Aucune de vos classes n'est en/
    sign_in_as @teacher
    get course_sheet_path(@course.slug, @devoir_sheet)
    assert_select "#assign_targets_none", 0
  end

  test "a teacher on the sheet to fill is redirected to the reading page" do
    sign_in_as @teacher

    get fill_course_sheet_path(@course.slug, @devoir_sheet)

    assert_redirected_to course_sheet_path(@course.slug, @devoir_sheet)
  end

  test "the team reads the sheet, drafts included, and is redirected from the page to fill" do
    draft = create_exercise(subject: @subject, course: @course, title: "Brouillon", status: "draft", position: 50)
    sign_in_as create_team_member

    get course_sheet_path(@course.slug, @devoir_sheet)

    assert_response :success
    assert_select "a.ps-start", 0
    assert_select paper(draft), 1
    assert_select ".ps-paper .ps-paper-exercise", 3
    assert_select "[id^=assignment_]", 0

    get fill_course_sheet_path(@course.slug, @devoir_sheet)

    assert_redirected_to course_sheet_path(@course.slug, @devoir_sheet)
  end

  test "the sheet page needs a session" do
    get course_sheet_path(@course.slug, @devoir_sheet)

    assert_redirected_to new_session_path
  end
end

require "test_helper"

# UDR sujet-comme-une-epreuve §3, PRD sujet-comme-une-epreuve §4 : la page de lecture d'une feuille se présente comme une épreuve
# (cartouche, titre, exercices avec leurs points, tableaux V/F et QCM, questions en liste), pour l'élève, l'enseignant et l'équipe.
class Catalog::SheetPaperTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Thalès", material: create_material(name: "Mathématiques"))
    @notion = create_essential(course: @course, name: "Réciproque", position: 1, sheet: { "remember" => "Retiens la réciproque." })
    @subject = create_subject(course: @course, title: "Sujet 1", notions: "Thalès, réciproque")
    @first = build_exercise(@subject, "Dans le triangle ABC, M est sur [AB].", hint: "Pense au rapport.") do |exercise|
      question(exercise, "true_false", "(MN) est parallèle à (BC).", answers: %w[Vrai Faux])
      4.times { |index| question(exercise, index == 3 ? "multiple_correct_2" : "single_choice", "Affirmation #{index + 2}", answers: %w[Un Deux Trois Quatre]) }
      question(exercise, "numeric", "Calcule AM.", unit: "cm")
    end
    @second = build_exercise(@subject, "Un second énoncé.") do |exercise|
      question(exercise, "numeric", "Calcule AN.", points: 2)
      question(exercise, "numeric", "Calcule AB.", points: 2)
    end
    @classroom = create_classroom(name: "3e 1", level: @course.level, series: @course.series)
    @student = create_student(classroom: @classroom)
    @teacher = create_teacher(classrooms: [ @classroom ])
  end

  def build_exercise(subject, statement, hint: nil)
    create_exercise(subject:, course: @course, questions: 0, statement:, hint:).tap { |exercise| yield exercise }
  end

  def question(exercise, type, content, answers: [], unit: nil, points: 1)
    position = exercise.questions.count + 1
    exercise.questions.create!(position:, content:, question_type: type, unit:, points:).tap do |created|
      answers.each_with_index { |text, rank| created.answers.create!(position: rank + 1, content: text, correct: rank.zero?) }
    end
  end

  def read(sheet = "sujet-#{@subject.position}") = course_sheet_path(@course.slug, sheet)
  def exercise_paper(exercise) = "section.ps-paper-exercise#sheet-exercise-#{exercise.public_id}"
  def including(text) = /#{Regexp.escape(text)}/

  test "the reading page is an exam paper: header, title, rubric, exercises with their points, footer, no field and no help" do
    sign_in_as @student

    get read

    assert_response :success
    assert_select "#sujet-#{@subject.position}.ps-sheet.ps-paper" do
      assert_select ".ps-header", text: including("PRÉPARE DEVOIRS")
      assert_select ".ps-header", text: including("MATHÉMATIQUES")
      assert_select "h1.ps-paper-heading", text: "ÉPREUVE DE MATHÉMATIQUES"
      assert_select "p.ps-paper-name", text: /\APrépare devoirs n°1 · .+/
      assert_select ".ps-paper-rubric", text: "Cette épreuve comporte 2 exercices."
      assert_select "h2.ps-paper-exercise-title", text: "Exercice 1 (6 points)"
      assert_select "h2.ps-paper-exercise-title", text: "Exercice 2 (4 points)"
      assert_select ".ps-paper-footer", text: "Sujet d'entraînement rédigé par Lnclass. Ce n'est pas un sujet officiel."
      assert_select "[data-controller=prepare-sheet]", 0
    end
    assert_select "a.ps-start", text: "Commencer l'exercice"
    assert_select ".ps-paper input, .ps-paper select, .ps-paper textarea, .ps-paper fieldset, .ps-paper form, .ps-paper button", 0
    assert_select ".ps-remember, .ps-progress, .ps-hint, .ps-actions", 0
    [ "Indice", "Pense au rapport.", "Notions mobilisées", "À retenir", "Vérifier ma réponse" ].each { assert_no_match including(it), response.body }
  end

  test "consecutive MCQs form a table with the columns N°, Affirmation, A, B, C, D, and a two-answer MCQ says so" do
    sign_in_as @student

    get read

    assert_select "#{exercise_paper(@first)} p.ps-paper-instruction", text: "Pour chacune des affirmations ci-dessous, trouve la ou les réponses exactes."
    assert_select "#{exercise_paper(@first)} table.ps-paper-table--mcq" do
      assert_select "caption.sr-only", text: "Exercice 1, affirmations b à e"
      assert_select "thead th[scope=col]", %w[N° Affirmation A B C D].size
      assert_select "thead th[scope=col]:nth-child(1)", text: "N°"
      assert_select "thead th[scope=col]:nth-child(2)", text: "Affirmation"
      %w[A B C D].each_with_index { |letter, index| assert_select "thead th:nth-child(#{index + 3})", text: letter }
      assert_select "tbody tr", 4
      assert_select "tbody tr:first-child th[scope=row]", text: "b"
      assert_select "tbody tr:last-child th[scope=row]", text: "e"
      %w[Un Deux Trois Quatre].zip(%w[A B C D]).each do |text, letter|
        assert_select "tbody tr:first-child td[data-letter=#{letter}]", text: text
      end
      assert_select "tbody tr:last-child .ps-instruction", text: "Coche 2 réponses."
      assert_select "tbody tr:first-child .ps-instruction", 0
    end
  end

  test "a true or false question forms a table with N° and Affirmation, and its instruction says V or F" do
    sign_in_as @student

    get read

    assert_select "#{exercise_paper(@first)} table.ps-paper-table--tf" do
      assert_select "caption.sr-only", text: "Exercice 1, affirmations a à a"
      assert_select "thead th[scope=col]", 2
      assert_select "tbody tr th[scope=row]", text: "a"
      assert_select "tbody tr td", text: including("(MN) est parallèle à (BC).")
    end
    assert_select "#{exercise_paper(@first)} p.ps-paper-instruction", text: "Pour chacune des affirmations ci-dessous, indique V si elle est vraie ou F si elle est fausse."
  end

  test "other questions stay in a list with their letter and unit, outside any table" do
    sign_in_as @student

    get read

    assert_select "#{exercise_paper(@first)} ol.ps-paper-list li", 1 do
      assert_select "b", text: "f."
    end
    assert_select "#{exercise_paper(@first)} ol.ps-paper-list li", text: /\Af\.\s*Calcule AM\.\s*…… cm\s*\z/
    assert_select "#{exercise_paper(@first)} table td", text: including("Calcule AM."), count: 0
    assert_select "#{exercise_paper(@second)} ol.ps-paper-list li", 2
    assert_select "#{exercise_paper(@second)} table", 0
  end

  test "a single-answer MCQ run says only one answer is right" do
    exercise = build_exercise(@subject, "QCM simple.") { |built| question(built, "single_choice", "Seule.", answers: %w[Un Deux]) }
    sign_in_as @student

    get read

    assert_select "#{exercise_paper(exercise)} p.ps-paper-instruction", text: "Pour chacune des affirmations ci-dessous, une seule réponse est exacte : trouve-la."
  end

  test "a fill-in question with two blanks shows two ellipses and no underscore marker" do
    exercise = build_exercise(@subject, "Trous.") do |built|
      question(built, "fill_blank", "Le côté ___ est l'___ du triangle.").tap do |created|
        2.times { |blank| created.answers.create!(position: blank + 1, content: "mot #{blank}", correct: true, blank:) }
      end
    end
    sign_in_as @student

    get read

    assert_select "#{exercise_paper(exercise)} ol.ps-paper-list li", text: /\Aa\.\s*Le côté … est l'… du triangle\.\s*\z/
    assert_no_match "___", css_select(exercise_paper(exercise)).first.text
    assert_select "#{exercise_paper(exercise)} input", 0
  end

  test "an ordering question lists its items without any field" do
    exercise = build_exercise(@subject, "Ordre.") do |built|
      question(built, "ordering", "Remets les étapes dans l'ordre.", answers: %w[Décomposer Séparer Calculer])
    end
    sign_in_as @student

    get read

    assert_select "#{exercise_paper(exercise)} ol.ps-paper-list li", text: including("Remets les étapes dans l'ordre.") do
      assert_select "ul.ps-paper-items li", 3
      %w[Décomposer Séparer Calculer].each { |item| assert_select "ul.ps-paper-items li", text: item }
    end
    assert_select "#{exercise_paper(exercise)} input, #{exercise_paper(exercise)} select, #{exercise_paper(exercise)} textarea", 0
  end

  test "a sequence resuming after another keeps its letters" do
    exercise = build_exercise(@subject, "Troisième.") do |built|
      question(built, "true_false", "Une affirmation.", answers: %w[Vrai Faux])
      question(built, "numeric", "Calcule.")
      question(built, "true_false", "Une autre.", answers: %w[Vrai Faux])
    end
    sign_in_as @student

    get read

    assert_select "#{exercise_paper(exercise)} table.ps-paper-table--tf", 2
    assert_select "#{exercise_paper(exercise)} table.ps-paper-table--tf:last-of-type tbody th[scope=row]", text: "c"
    assert_select "#{exercise_paper(exercise)} ol.ps-paper-list li b", text: "b."
  end

  test "an interros sheet has no « À retenir » when read, and still has it to fill" do
    create_exercise(essential: @notion, title: "Exercice notion")
    sign_in_as @student

    get read("notion-#{@notion.slug}")
    assert_response :success
    assert_select ".ps-remember", 0
    assert_no_match including("Retiens la réciproque."), response.body
    assert_select "h1.ps-paper-heading"

    get fill_course_sheet_path(@course.slug, "notion-#{@notion.slug}")
    assert_select ".ps-remember", text: including("Retiens la réciproque.")
  end

  test "an exercise title adds up its questions' points: 1, 1 and 0.5 make 2,5; one point is singular" do
    sum = build_exercise(@subject, "Somme.") do |exercise|
      question(exercise, "numeric", "Un.")
      question(exercise, "numeric", "Deux.")
      question(exercise, "numeric", "Trois.", points: 0.5)
    end
    single = build_exercise(@subject, "Seule.") { |exercise| question(exercise, "numeric", "Seule.") }
    bare = build_exercise(@subject, "Sans question.") { }
    sign_in_as @student

    get read

    assert_select "#{exercise_paper(sum)} h2", text: "Exercice 3 (2,5 points)"
    assert_select "#{exercise_paper(single)} h2", text: "Exercice 4 (1 point)"
    assert_select "#{exercise_paper(bare)} h2", text: "Exercice 5"
    assert_select "#{exercise_paper(bare)} table, #{exercise_paper(bare)} ol", 0
    assert_select "#{exercise_paper(bare)} p", text: including("Sans question.")
  end

  test "the teacher reads the same paper from her classroom with the toggles under each exercise and no « Commencer »" do
    sign_in_as @teacher

    get classroom_course_sheet_path(@classroom.public_id, @course.slug, "sujet-#{@subject.position}")

    assert_response :success
    assert_select "h1.ps-paper-heading", text: "ÉPREUVE DE #{@course.material.name.upcase}"
    assert_select "h2.ps-paper-exercise-title", text: "Exercice 1 (6 points)"
    assert_select "#{exercise_paper(@first)} table.ps-paper-table--mcq"
    [ @first, @second ].each do |exercise|
      assert_select "section#sheet-exercise-#{exercise.public_id}" do
        assert_select "#assignment_#{@classroom.public_id}_Exercise_#{exercise.public_id}"
        assert_select "button[data-batch-choice=?]", exercise.public_id
      end
    end
    assert_select "#sheet-batch-bar"
    assert_select "a.ps-start", 0
    assert_select ".ps-paper input, .ps-paper textarea, .ps-paper select, .ps-paper fieldset", 0
  end

  test "the team sees « Brouillon » on a draft exercise" do
    @second.update!(status: "draft", published_at: nil)
    sign_in_as create_team_member

    get classroom_course_sheet_path(@classroom.public_id, @course.slug, "sujet-#{@subject.position}")

    assert_response :success
    assert_select "#{exercise_paper(@second)} h2", text: including("Brouillon")
    assert_select "#{exercise_paper(@first)} h2", text: /Brouillon/, count: 0
    assert_select "a.ps-start", 0
  end
end

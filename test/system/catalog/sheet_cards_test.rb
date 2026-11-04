require "application_system_test_case"

# sujet-avant-de-commencer, Lot A (UDR feuilles-en-cases-lues-avant-de-commencer) : la leçon montre des cases ; la case ouvre le sujet en
# lecture ; « Commencer » ouvre la feuille à remplir ; la vérification ramène à la feuille ; la case dit le progrès et « Continuer ».
class Catalog::SheetCardsTest < ApplicationSystemTestCase
  setup do
    @course = create_course(name: "Thalès")
    @notion = create_essential(course: @course, name: "La propriété de Thalès", position: 1)
    @subject = create_subject(course: @course, title: "Sujet 2 · Démontrer")
    @exercises = Array.new(4) { |n| create_exercise(subject: @subject, course: @course, title: "Devoir #{n + 1}", position: 10 + n, questions: 1) }
    @student = create_student(classroom: create_classroom(level: @course.level, series: @course.series))
    sign_in_as @student
  end

  def frame(exercise) = "#sheet-exercise-#{exercise.public_id}"

  test "case, lecture, Commencer, vérifier, retour à la feuille, puis « Continuer » et le progrès sur la case" do
    visit course_path(@course.slug)
    assert_selector "a.ps-card", count: 1
    assert_no_selector ".ps-sheet"
    assert_no_button "Vérifier ma réponse"
    assert_selector "#sujet-#{@subject.position} .ps-card-meta", text: "0 / 4 exercice réussi"

    click_link "Prépare devoirs n°1"
    assert_selector "h1.ps-paper-heading", text: /\AÉPREUVE DE /
    assert_selector ".ps-paper-name", text: "Prépare devoirs n°1", exact_text: false
    assert_selector ".ps-paper-exercise", count: 4
    assert_no_selector "fieldset, input, textarea, select"
    assert_no_selector ".ps-remember"
    assert_no_button "Vérifier ma réponse"
    assert_no_button "Indice"

    click_link "Commencer Prépare devoirs"
    assert_current_path fill_course_sheet_path(@course.slug, "sujet-#{@subject.position}")
    within(frame(@exercises.first)) do
      click_button "A."
      click_button "Vérifier ma réponse"
    end

    assert_selector "#session_grade"
    click_link "Continuer les exercices"
    assert_current_path fill_course_sheet_path(@course.slug, "sujet-#{@subject.position}")
    within(frame(@exercises.first)) { assert_selector ".ps-status", text: "Réussi" }

    visit course_path(@course.slug)
    assert_selector "#sujet-#{@subject.position} .ps-card-meta", text: "1 / 4 exercice réussi"
    find("a.ps-card#sujet-#{@subject.position}").click
    assert_link "Continuer Prépare devoirs"
  end

  test "on a 390 px screen the reading page does not overflow and « Commencer » is 48 px high" do
    with_mobile_viewport do
      visit course_sheet_path(@course.slug, "sujet-#{@subject.position}")

      assert_selector "a.ps-start"
      assert_operator page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"), :<=, 0
      assert_operator find("a.ps-start").rect.height, :>=, 48
    end
  end

  # sujet-comme-une-epreuve : les tableaux V/F et QCM et une formule trop large tiennent dans l'écran, la page ne défile pas de côté.
  test "on a 390 px screen the exam paper with a QCM table, a true or false table and a long formula does not scroll sideways" do
    formula = "$$" + Array.new(14) { |i| "\\int_{#{i}}^{#{i + 1}} f(x)\\,dx" }.join(" + ") + "$$"
    subject = create_subject(course: @course, title: "Sujet 3 · Épreuve")
    exercise = create_exercise(subject:, course: @course, title: "Épreuve", questions: 0, statement: "Un énoncé assez long pour passer à la ligne sur un téléphone.")
    exercise.questions.create!(position: 1, content: "Une affirmation de vrai ou faux assez longue pour passer à la ligne.", question_type: "true_false")
          .tap { |q| %w[Vrai Faux].each_with_index { |c, i| q.answers.create!(position: i + 1, content: c, correct: i.zero?) } }
    2.times do |index|
      exercise.questions.create!(position: index + 2, content: "Affirmation #{formula}", question_type: "single_choice").tap do |q|
        [ "Une proposition assez longue", "Deux", "Trois", formula ].each_with_index { |c, i| q.answers.create!(position: i + 1, content: c, correct: i.zero?) }
      end
    end

    with_mobile_viewport do
      visit course_sheet_path(@course.slug, "sujet-#{subject.position}")

      assert_selector "table.ps-paper-table--tf", count: 1
      assert_selector "table.ps-paper-table--mcq", count: 1
      assert_selector ".ps-paper-table .katex-display", minimum: 1, wait: 10
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, 390
      sheet_right = find(".ps-paper").rect.x + find(".ps-paper").rect.width
      all(".ps-paper-table").each { |table| assert_operator table.rect.x + table.rect.width, :<=, sheet_right + 0.5 }
      # UDR §3 sous 480 px : l'affirmation, puis ses propositions deux par deux (A et B sur une ligne, C dessous).
      cells = %w[A B C].to_h { |letter| [ letter, find("table.ps-paper-table--mcq tbody tr:first-child td[data-letter=#{letter}]").rect ] }
      assert_in_delta cells["A"].y, cells["B"].y, 2
      assert_operator cells["A"].x, :<, cells["B"].x
      assert_operator cells["C"].y, :>, cells["A"].y
    end
  end
end

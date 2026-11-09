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

  # feuille-pleine-largeur (UDR « feuille pleine largeur sur téléphone ») : sous 640 px la feuille touche les deux bords de l'écran.
  def assert_sheet_edge_to_edge
    rect = find(".ps-sheet").rect
    width = page.evaluate_script("document.documentElement.clientWidth")
    assert_in_delta 0, rect.x, 0.5
    assert_in_delta width, rect.x + rect.width, 0.5
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, width
  end

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

    find("a.ps-start", text: "Commencer l'exercice").click
    assert_current_path fill_course_sheet_path(@course.slug, "sujet-#{@subject.position}")
    within(frame(@exercises.first)) do
      click_button "A."
      click_button "Vérifier ma réponse"
    end

    assert_selector "#session_badge"
    click_link "Continuer les exercices"
    assert_current_path fill_course_sheet_path(@course.slug, "sujet-#{@subject.position}")
    within(frame(@exercises.first)) { assert_selector ".ps-status", text: "Réussi" }

    visit course_path(@course.slug)
    assert_selector "#sujet-#{@subject.position} .ps-card-meta", text: "1 / 4 exercice réussi"
    find("a.ps-card#sujet-#{@subject.position}").click
    assert_selector "a.ps-start", text: "Commencer l'exercice"
  end

  test "on a 390 px screen the reading page does not overflow and « Commencer » is 48 px high" do
    with_mobile_viewport do
      visit course_sheet_path(@course.slug, "sujet-#{@subject.position}")

      assert_selector "a.ps-start"
      assert_operator page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"), :<=, 0
      assert_operator find("a.ps-start").rect.height, :>=, 48
      assert_sheet_edge_to_edge
      button = find("a.ps-start").rect
      assert_in_delta find(".ps-sheet .ps-header").rect.x, button.x, 2
      assert_operator button.x + button.width, :<, page.evaluate_script("document.documentElement.clientWidth") - 8

      visit fill_course_sheet_path(@course.slug, "sujet-#{@subject.position}")
      assert_selector ".ps-sheet"
      assert_sheet_edge_to_edge
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

  # feuilles-rendues (UDR-0152 §3, amendement du 2026-11-06) : sur ordinateur, les colonnes de lettres prennent la taille de leurs
  # propositions, qui ne défilent plus dans leur case ; un QCM qui ne tient pas ainsi s'empile comme sur téléphone.
  test "on a computer a QCM table sizes its letter columns to the choices, and stacks when it cannot fit" do
    subject = create_subject(course: @course, title: "Sujet 3 · Les alcanes")
    exercise = create_exercise(subject:, course: @course, title: "Alcanes", questions: 0, statement: "On étudie les alcanes.")
    words = exercise.questions.create!(position: 1, content: "Quel alcane a 5 atomes de carbone ?", question_type: "single_choice")
    [ "L'heptane", "L'octane", "L'hexane", "Le pentane" ].each_with_index { |c, i| words.answers.create!(position: i + 1, content: c, correct: i == 3) }
    exercise.questions.create!(position: 2, content: "Un alcane ne contient que du carbone et de l'hydrogène.", question_type: "true_false")
            .tap { |q| %w[Vrai Faux].each_with_index { |c, i| q.answers.create!(position: i + 1, content: c, correct: i.zero?) } }
    chain = ->(n) { "$\\mathrm{" + Array.new(n) { "CH_2" }.join("-") + "}$" }
    formulas = exercise.questions.create!(position: 3, content: "Quelle chaîne a le plus de carbones ?", question_type: "single_choice")
    [ 6, 7, 8, 9 ].each_with_index { |n, i| formulas.answers.create!(position: i + 1, content: chain.(n), correct: i == 3) }

    visit course_sheet_path(@course.slug, "sujet-#{subject.position}")

    tables = all("table.ps-paper-table--mcq", count: 2)
    assert_selector "table.ps-paper-table--mcq .katex", minimum: 4, wait: 10
    # Les mots tiennent : le tableau reste un tableau, aucune proposition ne défile, « Le pentane » n'est pas coupé.
    assert_no_selector "table.ps-paper-table--mcq.ps-paper-table--stacked", text: "Le pentane", wait: 2
    assert_equal "table", tables.first.evaluate_script("getComputedStyle(this).display")
    cut = tables.first.evaluate_script("[...this.querySelectorAll('.ps-paper-choice')].filter((c) => c.scrollWidth > c.clientWidth + 1).length")
    assert_equal 0, cut
    # Les quatre chaînes ne tiennent pas en colonnes à côté de l'affirmation : le QCM s'empile, sans élargir la page.
    assert_selector "table.ps-paper-table--mcq.ps-paper-table--stacked", text: "Quelle chaîne", wait: 5
    assert_equal "grid", tables.last.find("tbody tr").evaluate_script("getComputedStyle(this).display")
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, page.evaluate_script("window.innerWidth")
    # Le repli se défait : plus étroit, le tableau de mots s'empile (affirmation sous 10 em) ; rendu large, il redevient un tableau.
    window = page.current_window
    original = window.size
    window.resize_to(600, 900)
    assert_selector "table.ps-paper-table--mcq.ps-paper-table--stacked", text: "Le pentane", wait: 5
    window.resize_to(*original)
    assert_no_selector "table.ps-paper-table--mcq.ps-paper-table--stacked", text: "Le pentane", wait: 5
  ensure
    window&.resize_to(*original) if original
  end

  # feuilles-rendues : à 390 px, une équation plus longue que la ligne fait défiler sa question, jamais la page ; une fraction
  # n'est pas rognée par ce cadre ; une formule finie par un indice dans une case de QCM n'a pas de barre de défilement.
  test "on a 390 px screen a long equation scrolls its question, a fraction is not clipped and CO2 shows no scrollbar" do
    subject = create_subject(course: @course, title: "Sujet 3 · Combustion")
    exercise = create_exercise(subject:, course: @course, title: "Combustion", questions: 0, statement: "On étudie une combustion.")
    gases = exercise.questions.create!(position: 1, content: "Quel gaz se forme ?", question_type: "single_choice")
    [ "$\\mathrm{CO_2}$", "$\\mathrm{H_2}$", "$\\mathrm{O_2}$", "$\\mathrm{N_2}$" ].each_with_index { |c, i| gases.answers.create!(position: i + 1, content: c, correct: i.zero?) }
    equation = "L'octane $\\mathrm{CH_3-CH_2-CH_2-CH_2-CH_2-CH_2-CH_2-CH_3}$ a ___ atomes de carbone."
    exercise.questions.create!(position: 2, content: equation, question_type: "fill_blank").answers.create!(position: 1, content: "8", correct: true, blank: 0)
    exercise.questions.create!(position: 3, content: "Le quotient $\\dfrac{12}{4}$ vaut ___.", question_type: "fill_blank").answers.create!(position: 1, content: "3", correct: true, blank: 0)

    with_mobile_viewport do
      visit course_sheet_path(@course.slug, "sujet-#{subject.position}")
      assert_selector ".ps-paper-list .katex", minimum: 2, wait: 10
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, 390
      clipped = page.evaluate_script("[...document.querySelectorAll('.ps-paper-list > li')].filter((li) => li.scrollHeight > li.clientHeight + 1).length")
      assert_equal 0, clipped
      assert_formulas_fit
    end
  end

  # Chaque formule en ligne d'un tableau de sujet tient dans son cadre (KaTeX ôte 2 px après un indice, rendus par prepare_sheet.css).
  def assert_formulas_fit
    assert_selector ".ps-paper-table .katex", minimum: 1, wait: 10
    over = page.evaluate_script("[...document.querySelectorAll('.ps-paper-table .katex')].filter((k) => k.scrollWidth > k.clientWidth).map((k) => k.textContent.slice(0, 20))")
    assert_empty over
  end
end

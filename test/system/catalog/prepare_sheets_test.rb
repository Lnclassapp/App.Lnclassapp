require "application_system_test_case"

# prepare-interros-cahier, Lot B (CA-1, 2, 6, 7, 11), UDR feuilles-prepare-interros-et-devoirs §3 (Comportement) : l'élève lit les feuilles,
# répond, garde ses réponses au rechargement, lit l'indice, refait l'exercice et recommence la feuille, sans requête.
class Catalog::PrepareSheetsTest < ApplicationSystemTestCase
  setup do
    @course = create_course(name: "Thalès")
    @notion = create_essential(course: @course, name: "La propriété de Thalès", position: 1, sheet: { "remember" => "AM/AB = AN/AC." })
    @exercise = create_exercise(essential: @notion, title: "Premier", questions: 0, hint: "Écris les côtés du petit triangle.")
    @mcq = @exercise.questions.create!(position: 1, content: "Quelle égalité est vraie ?", question_type: "single_choice")
    [ "AM/AB = AN/AC", "AM/MB = AN/NC", "AB/AM = AN/AC", "Aucune" ].each_with_index do |content, index|
      @mcq.answers.create!(position: index + 1, content:, correct: index.zero?)
    end
    @fill = create_kind_question(exercise: @exercise, question_type: "fill_blank", content: "AM/AB = AN/___", answers: [ "AC" ])
    @second = create_exercise(essential: @notion, title: "Second", questions: 1)
    @student = create_student(classroom: create_classroom(level: @course.level, series: @course.series))
    sign_in_as @student
  end

  def frame(exercise) = "#sheet-exercise-#{exercise.public_id}"

  # CA-1, CA-6
  test "the student reads the sheet, opens the hint and answers a question" do
    visit course_path(@course.slug)

    within ".ps-sheet#notion-#{@notion.slug}" do
      assert_text "PRÉPARE INTERROS"
      assert_selector ".ps-title", text: "LA PROPRIÉTÉ DE THALÈS"
      assert_text "À retenir : AM/AB = AN/AC."
      within frame(@exercise) do
        assert_no_selector ".ps-hint"
        click_button "Indice"
        assert_selector ".ps-hint", text: "Indice : Écris les côtés du petit triangle."
        assert_selector "button.ps-btn--hint[aria-expanded=true]", text: "Masquer l'indice"
        click_button "Masquer l'indice"
        assert_no_selector ".ps-hint"
        click_button "B."
        assert_selector "button[role=radio][aria-checked=true]", count: 1
        assert_selector "button[role=radio][aria-checked=true]", text: "AM/MB = AN/NC"
        click_button "C."
        assert_selector "button[role=radio][aria-checked=true]", text: "AB/AM = AN/AC"
        assert_selector "button[role=radio][aria-checked=true]", count: 1
      end
    end
  end

  # CA-1 : ses réponses restent dans le navigateur
  test "the answers not yet checked survive a reload" do
    visit course_path(@course.slug)
    within frame(@exercise) do
      click_button "B."
      find("input.ps-input").set("AC")
      assert_selector "input.ps-input--filled"
    end

    visit course_path(@course.slug)

    within frame(@exercise) do
      assert_selector "button[role=radio][aria-checked=true]", text: "AM/MB = AN/NC"
      assert_equal "AC", find("input.ps-input").value
    end
    assert_no_selector "#{frame(@second)} button[aria-checked=true]"
  end

  # CA-7
  test "« Refaire l'exercice » and « Recommencer cette notion » put the sheet back to blank, and it stays blank on reload" do
    [ @exercise, @second ].each do |exercise|
      session = create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 50)
      session.update!(correct_count: 1, question_count: exercise.questions.count)
      exercise.questions.each do |question|
        Orm::QuestionAttempt.create!(exercise_session: session, question:, correct: true, answered_at: Time.current,
                                     selected_answer_ids: question.question_type == "fill_blank" ? [] : [ question.answers.order(:position).first.id ],
                                     response_text: ("AC" if question.question_type == "fill_blank"))
      end
    end
    visit course_path(@course.slug)

    within frame(@exercise) do
      assert_link "Voir ma correction"
      assert_selector "button[role=radio][aria-checked=true]", text: "AM/AB = AN/AC"
      assert_no_button "Vérifier ma réponse"
      click_button "Refaire l'exercice"
      assert_no_link "Voir ma correction"
      assert_button "Vérifier ma réponse"
      assert_no_selector "button[aria-checked=true]"
      assert_equal "", find("input.ps-input").value
    end
    assert_selector "#{frame(@second)} a", text: "Voir ma correction"

    visit course_path(@course.slug)
    within(frame(@exercise)) { assert_button "Vérifier ma réponse" }
    assert_selector "#{frame(@second)} a", text: "Voir ma correction"

    click_button "Recommencer cette notion"
    assert_no_link "Voir ma correction"
    assert_selector "button.ps-btn--primary", text: "Vérifier ma réponse", count: 2
  end

  # CA-11
  test "on a 390 px screen no sheet overflows and every button is at least 44 px high" do
    visit course_path(@course.slug)

    with_mobile_viewport do
      assert_selector ".ps-sheet"
      overflow = page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      assert_operator overflow, :<=, 0
      heights = page.evaluate_script("Array.from(document.querySelectorAll('.ps-btn')).filter(b => b.offsetParent !== null).map(b => b.getBoundingClientRect().height)")
      assert_not_empty heights
      assert heights.all? { it >= 44 }, "boutons de #{heights.min} px"
    end
  end
end

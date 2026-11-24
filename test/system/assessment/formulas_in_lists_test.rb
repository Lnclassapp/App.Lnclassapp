require "application_system_test_case"

# Chantier premier-exercice-formules-soumission : sur la copie de l'élève, une proposition en formule ($\ln 7$) d'une liste
# (choix dans une liste, relier, remettre dans l'ordre) restait en LaTeX brut, et la copie devait pouvoir partir.
# Contenu tiré d'une vraie leçon (Tle A2, fonction exponentielle népérienne).
class Assessment::FormulasInListsTest < ApplicationSystemTestCase
  setup do
    @exercise = create_exercise(title: "Réciproque de l'exponentielle", questions: 0)
    @select = @exercise.questions.create!(position: 1, content: "Complète : $e^{x} = 7 \\iff x =$ ___", question_type: "select")
    [ "$e^{7}$", "$\\dfrac{1}{7}$", "$\\ln 7$" ].each_with_index { |text, rank| @select.answers.create!(position: rank + 1, content: text, correct: rank == 2) }
    @below = @exercise.questions.create!(position: 2, content: "L'ensemble des solutions de $e^{x} = -3$ est :", question_type: "select")
    [ "$\\varnothing$", "$\\{\\ln 3\\}$" ].each_with_index { |text, rank| @below.answers.create!(position: rank + 1, content: text, correct: rank.zero?) }
    @student = create_student_for(@exercise.essential.course)
    @session = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student
  end

  test "les propositions en formule d'une liste se lisent rendues, jamais en LaTeX brut, et la copie part" do
    visit exercise_session_path(@session.public_id)

    within("#question-1") do
      assert_selector ".katex", minimum: 4 # la phrase, puis les trois propositions
      assert_no_text "\\ln 7"
      assert_no_text "dfrac"
    end
    within("#question-2") do
      assert_selector ".katex", minimum: 3
      assert_no_text "varnothing"
    end
    # Aucune option d'un menu ne montre de LaTeX : une option ne peut pas porter de formule rendue.
    options = all("#copy-form option", visible: :all).map(&:text)
    assert(options.none? { it.include?("$") || it.include?("\\") }, "options en LaTeX brut : #{options.inspect}")

    pick(1, @select.answers.find_by!(correct: true))
    pick(2, @below.answers.find_by!(correct: true))
    assert_selector "#copy-counter", text: "2/2"
    click_on I18n.t("assessment.exercise_sessions.show.submit")

    assert_selector "#session_badge"
    assert_equal 100, @session.reload.score_percent
  end

  private

  # La proposition se retrouve par sa formule (l'annotation TeX que KaTeX garde), puis l'option de même valeur se choisit.
  def pick(number, answer)
    tex = answer.content.delete_prefix("$").delete_suffix("$")
    shown = all("#question-#{number} [data-option-value]").find { it.find("annotation", visible: :all).text(:all) == tex }
    assert shown, "proposition #{answer.content} introuvable sous la question #{number}"
    find("#question-#{number} select option[value='#{shown["data-option-value"]}']", visible: :all).select_option
  end
end

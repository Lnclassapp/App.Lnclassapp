require "test_helper"

# correction-comme-en-classe, Lot C (UDR-0140 §3) : la feuille d'un devoir. Choix dans une liste, unité, réponse rédigée,
# travail sur le cahier, points (CA-17 à CA-21, CA-24). Jamais une bonne réponse, un corrigé type ni une grille avant la
# vérification (CA-05). La feuille de l'enseignant montre la solution des nouveaux types, celle de l'élève jamais.
class Assessment::ExerciseSessionsNewKindsTest < ActionDispatch::IntegrationTest
  GRID = [ "Je cite le théorème de Thalès", "Je conclus par une phrase" ].freeze

  setup do
    @exercise = create_exercise(title: "Devoir", questions: 0, exercise_type: "evaluation")
    @course = @exercise.essential.course
    @student = create_student_for(@course)
    @select = question("select", "Les points A, M et B doivent être ___.", points: 2, answers: [ "parallèles", "alignés", "proportionnelles" ], correct: 1)
    @loose = question("select", "On sait que (MN) // (BC) et on cherche une longueur.", answers: [ "Thalès", "Pythagore" ], correct: 0)
    @numeric = question("numeric", "Calcule AM.", unit: "cm", answers: [ "4,8" ], correct: 0)
    @written = question("written", "Le point est-il sur la droite ?", points: 2, starter: "Non, car…", explanation: "Corrigé secret : oui.", criteria: GRID)
    @notebook = question("notebook", "Sur ton cahier, trace la construction.", points: 2, explanation: "Corrigé du cahier : tracer (d).")
    @session = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student
  end

  def question(type, content, answers: [], correct: nil, **attributes)
    @exercise.questions.create!(position: @exercise.questions.count + 1, content:, question_type: type, **attributes).tap do |created|
      answers.each_with_index do |text, rank|
        created.answers.create!(position: rank + 1, content: text, correct: rank == correct)
      end
    end
  end

  def sheet(question) = "#question-#{@exercise.questions.order(:position).pluck(:id).index(question.id) + 1}"

  test "CA-18 : la liste remplace le trou, rien n'est choisi au départ, aucune bonne réponse dans la page" do
    get exercise_session_path(@session.public_id)

    assert_response :success
    assert_select "#{sheet(@select)} select[name='copy[answers][#{@select.id}][display_order][]']" do |selects|
      assert_match(/blanc/, selects.first["aria-label"])
      assert_select "option", 4
      assert_select "option[selected]", 0
      assert_select "option[value='']", text: I18n.t("assessment.exercise_sessions.kinds.select.choose")
    end
    assert_select "#{sheet(@select)} option", text: "alignés"
    assert_select "#{sheet(@select)} [data-correct], #{sheet(@select)} [checked]", 0
    assert_no_match(/value="#{@select.answers.find_by(correct: true).id}"/, response.body)
  end

  test "CA-19 : sans trou, la liste est sous la question, en pleine largeur" do
    get exercise_session_path(@session.public_id)

    assert_select "#{sheet(@loose)} legend", text: /On sait que/
    assert_select "#{sheet(@loose)} select.w-full", 1
  end

  test "CA-20 : l'unité suit le champ, liée par aria-describedby" do
    get exercise_session_path(@session.public_id)

    unit_id = css_select("#{sheet(@numeric)} input[type=text]").first["aria-describedby"].split.find { it.include?("unit") }
    assert_select "##{unit_id}", text: "cm"
  end

  test "CA-21 : la zone de texte est vide, son exemple est le début de phrase, 2 000 caractères au plus, compteur Stimulus" do
    get exercise_session_path(@session.public_id)

    assert_select "#{sheet(@written)} textarea[maxlength='2000'][rows='6'][placeholder='Non, car…']", text: ""
    assert_select "#{sheet(@written)} [data-controller~='assessment--counter']"
    assert_select "#{sheet(@written)} [data-assessment--counter-target='output']", text: /0 \/ 2.000/
  end

  test "CA-24 : le travail sur le cahier montre la consigne et « À faire sur ton cahier », sans champ" do
    get exercise_session_path(@session.public_id)

    assert_select "#{sheet(@notebook)} legend", text: /Sur ton cahier, trace la construction/
    assert_select "#{sheet(@notebook)}", text: /#{I18n.t("assessment.exercise_sessions.kinds.notebook.to_do")}/
    assert_select "#{sheet(@notebook)} input, #{sheet(@notebook)} textarea, #{sheet(@notebook)} select", 0
  end

  test "CA-17 : les points suivent chaque légende quand une question n'est pas à 1 point ; 1 point au singulier" do
    get exercise_session_path(@session.public_id)

    assert_select "#{sheet(@select)} legend", text: /\(2 points\)/
    assert_select "#{sheet(@loose)} legend", text: /\(1 point\)/
    @loose.update!(points: 1.5)
    get exercise_session_path(@session.public_id)
    assert_select "#{sheet(@loose)} legend", text: /\(1,5 point\)/
  end

  test "CA-17 : un exercice tout à 1 point n'affiche aucun point" do
    @exercise.questions.update_all(points: 1)

    get exercise_session_path(@session.public_id)

    assert_select "legend", text: /\(\d[\d,]* points?\)/, count: 0
  end

  test "CA-05 : la feuille d'une copie en cours, avec une réponse rédigée, ne montre ni bonne réponse, ni corrigé type, ni grille" do
    Orm::QuestionAttempt.create!(exercise_session: @session, question: @written, correct: false, selected_answer_ids: [],
                                 response_text: "Brouillon de l'élève", answered_at: Time.current)

    get exercise_session_path(@session.public_id)

    assert_response :success
    [ "Corrigé secret", "Corrigé du cahier", *GRID, I18n.t("assessment.session_results.question_review.model_answer"),
      I18n.t("assessment.session_results.question_review.criteria") ].each { assert_not_includes response.body, it }
    assert_select "input[type=checkbox]", 0
    assert_not_includes response.body, @numeric.answers.first.content
  end

  test "menace W7 : le début de phrase n'est qu'un exemple (placeholder), jamais la valeur de la zone" do
    get exercise_session_path(@session.public_id)

    assert_select "#{sheet(@written)} textarea" do |areas|
      assert_equal "", areas.first.text.to_s.strip
      assert_nil areas.first["value"]
    end
  end

  test "feuille de l'enseignant : la liste marque la bonne proposition, la réponse rédigée montre le corrigé type et la grille" do
    sign_out
    sign_in_as create_team_member

    get exercise_path(@exercise.public_id)

    assert_response :success
    assert_select "#sheet-question-1 li.answer[data-correct]", text: /alignés/
    assert_select "#sheet-question-4", text: /Corrigé secret : oui\./
    GRID.each { assert_select "#sheet-question-4 li", text: it }
    assert_select "#sheet-question-5", text: /Corrigé du cahier/
    assert_select "#sheet-question-4 input, #sheet-question-4 textarea", 0
    assert_select "#sheet-question-3", text: /cm/
  end

  test "feuille de l'élève : ni bonne proposition, ni corrigé type, ni grille" do
    get exercise_path(@exercise.public_id)

    assert_response :success
    assert_select "[data-correct]", 0
    [ "Corrigé secret", "Corrigé du cahier", *GRID ].each { assert_not_includes response.body, it }
    assert_select "#sheet-question-1 li.answer", 3
    assert_select "#sheet-question-4", text: /Le point est-il sur la droite/
  end
end

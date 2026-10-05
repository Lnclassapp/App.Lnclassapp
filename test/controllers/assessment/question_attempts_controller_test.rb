require "test_helper"

# AS-09, AS-10, AS-11 (UDR-0022) : répondre une fois à une question, voir son verdict et sa progression en Turbo Stream,
# une réponse vide en 422 dans la carte (jamais 500, C-10), une re-soumission refusée sans rien écrire (C-11), la
# dernière réponse qui clôt la session et propose le résultat. La correction ne montre jamais les propositions correctes.
class Assessment::QuestionAttemptsControllerTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze
  ERRORS = "activemodel.errors.models.dtos/assessment/attempt_input.attributes".freeze

  setup do
    @exercise = create_exercise(title: "Méiose", questions: 2)
    # UDR-0013, amendement du 2026-10-01 : la classe de l'élève est du niveau du cours.
    @student = create_student_for(@exercise.essential.course)
    @first, @second = @exercise.questions.order(:position).to_a
    @first.update!(explanation: "La méiose donne quatre cellules.")
    # UDR-0076 §3.3 : le stream joint la question suivante ; ses propositions ont leurs propres textes, pour qu'un test
    # anti-fuite ne confonde jamais une proposition de la question suivante avec la correction de la question tentée.
    @second.update!(content: "La méiose réduit-elle le nombre de chromosomes ?")
    @second.answers.each { it.update!(content: "Choix #{it.position} de la question 2") }
    @session = create_exercise_session(student: @student, exercise: @exercise)
  end

  def scope = "assessment.exercise_sessions"
  def right(question) = question.answers.find_by!(correct: true)
  def wrong(question) = question.answers.where(correct: false).order(:id).first

  def answer(question, *answers, session: @session, headers: TURBO)
    post exercise_session_attempts_path(session.public_id), headers:,
                                                            params: { attempt: { question_id: question.id, answer_ids: answers.map(&:id) } }
  end

  test "une mauvaise réponse : tentative enregistrée, verdict, choix de l'élève, explication, progression, question suivante" do
    sign_in_as @student

    answer @first, wrong(@first)

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    attempt = Orm::QuestionAttempt.sole
    assert_equal [ @session.id, @first.id, [ wrong(@first).id ], false ],
                 [ attempt.exercise_session_id, attempt.question_id, attempt.selected_answer_ids, attempt.correct ]
    assert_not_nil attempt.answered_at
    assert_equal [ 1, 0, 50 ], @session.reload.values_at(:answered_count, :correct_count, :progress_percent)

    assert_select "turbo-stream[action=replace][target=question] template" do
      assert_select "turbo-frame#question #feedback-card", text: /#{I18n.t("#{scope}.feedback_card.verdict.error")}/
      assert_select "#feedback-card", text: /La méiose donne quatre cellules/
      assert_select "#feedback-card", text: /#{I18n.t("#{scope}.feedback_card.selected")}/
      assert_select "#feedback-card li", text: wrong(@first).content, count: 1
      assert_select "a[href='#{exercise_session_path(@session.public_id)}']", text: I18n.t("#{scope}.feedback_card.next")
    end
    assert_select "turbo-stream[action=replace][target=progress_bar] template progress[value='50']"
  end

  # UDR-0076 §3.3 (CA-7), ADR-0076 : la question suivante arrive avec le verdict, dans un <template> de la carte ; « Question
  # suivante » l'affiche sans requête, et reste un lien vers la session (repli sans JavaScript), sans préchargement.
  test "le verdict joint la question suivante, sans aucune correction : un aller-retour par question" do
    sign_in_as @student

    answer @first, wrong(@first)

    assert_select "turbo-stream[action=replace][target=question] template turbo-frame#question " \
                  "#feedback-card[data-controller='assessment--next-question']" do
      assert_select "a[href=?][data-action='assessment--next-question#show'][data-turbo-prefetch=false]",
                    exercise_session_path(@session.public_id), text: I18n.t("#{scope}.feedback_card.next")
      assert_select "template[data-assessment--next-question-target=question] turbo-frame#question #question-card" do
        assert_select "legend", text: "La méiose réduit-elle le nombre de chromosomes ?"
        assert_select "form[action=?]", exercise_session_attempts_path(@session.public_id)
        assert_select "input[type=hidden][name='attempt[question_id]'][value=?]", @second.id.to_s
        assert_equal @second.answers.pluck(:id).map(&:to_s).sort,
                     css_select("input[type=radio][name='attempt[answer_ids][]']").map { it["value"] }.sort
      end
    end
    assert_select "[data-correct], [correct]", 0
    assert_no_match(/correct/i, response.body.scan(/<template data-assessment--next-question-target.*?<\/template>/m).join)
  end

  # ADR-0076 §4.1 (CA-8) : ni la page de la session ni le stream d'une réponse ne vont dans un cache partagé.
  test "ADR-0076 — la session et le stream d'une réponse ne sont jamais publics en cache" do
    sign_in_as @student

    get exercise_session_path(@session.public_id)
    page = response.headers["Cache-Control"]
    answer @first, wrong(@first)

    [ page, response.headers["Cache-Control"] ].each do |header|
      assert_match(/private|no-store/, header)
      assert_no_match(/public/, header)
    end
  end

  test "la correction ne contient jamais le texte d'une proposition juste que l'élève n'a pas choisie" do
    sign_in_as @student

    answer @first, wrong(@first)

    assert_no_match right(@first).content, response.body
    assert_no_match(/proposition correcte|data-correct/i, response.body)
    assert_select "#feedback-card li" do |items|
      assert_equal [ wrong(@first).content ], items.map { it.text.strip }
    end
  end

  test "deux propositions correctes, une seule trouvée : l'autre n'apparaît ni dans la carte ni dans le stream" do
    @second.update!(question_type: "multiple_correct_2")
    found, missed, chosen_wrong = @second.answers.order(:position).first(3)
    missed.update!(correct: true)
    sign_in_as @student

    answer @second, found, chosen_wrong

    assert_select "#feedback-card", text: /#{I18n.t("#{scope}.feedback_card.verdict.error")}/
    assert_select "#feedback-card li" do |items|
      assert_equal [ found.content, chosen_wrong.content ], items.map { it.text.strip }
    end
    assert_no_match missed.content, response.body
  end

  test "la dernière réponse clôt la session dans la même requête : score, badge, lien vers le résultat" do
    create_attempt(session: @session, question: @first, correct: true)
    @session.update!(answered_count: 1, correct_count: 1, progress_percent: 50)
    sign_in_as @student

    answer @second, right(@second)

    @session.reload
    assert_equal [ "completed", 100, 2 ], @session.values_at(:status, :score_percent, :answered_count)
    assert_not_nil @session.completed_at
    assert_equal "diamond", Orm::ExerciseBadge.find_by!(student: @student, exercise: @exercise).level
    assert_select "#feedback-card", text: /#{I18n.t("#{scope}.feedback_card.verdict.success")}/
    assert_select "#feedback-card a[href='#{exercise_session_result_path(@session.public_id)}'][data-turbo-frame=_top]",
                  text: I18n.t("#{scope}.feedback_card.result")
    assert_select "template[data-assessment--next-question-target]", 0
    assert_select "[data-controller='assessment--next-question']", 0
  end

  test "réponse vide en Turbo : 422 dans la carte, avec « Sélectionne au moins une proposition. », jamais 500" do
    sign_in_as @student

    post exercise_session_attempts_path(@session.public_id), headers: TURBO, params: { attempt: { question_id: @first.id } }

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=replace][target=question] template turbo-frame#question #question-card" do
      assert_select "#attempt-errors[role=alert]", text: I18n.t("#{ERRORS}.answer_ids.blank")
      assert_select "input[type=radio]", 4
    end
    assert_equal 0, Orm::QuestionAttempt.count
  end

  test "trop ou trop peu de propositions, ou celle d'une autre question : 422, rien n'est écrit" do
    sign_in_as @student

    answer @first, right(@first), wrong(@first)
    assert_response :unprocessable_entity
    assert_select "#attempt-errors", text: I18n.t("#{ERRORS}.answer_ids.wrong_selection")

    answer @first, right(@second)
    assert_response :unprocessable_entity
    assert_equal 0, Orm::QuestionAttempt.count
  end

  test "question déjà répondue : rien n'est écrit, toast et retour à l'état de la session" do
    create_attempt(session: @session, question: @first, correct: false)
    sign_in_as @student

    answer @first, right(@first)

    assert_response :success
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{I18n.t("#{ERRORS}.base.already_answered")}/
    assert_select "turbo-stream[action=refresh]"
    assert_equal [ false ], Orm::QuestionAttempt.pluck(:correct)
  end

  test "session terminée : même refus, sans écriture" do
    @session.update!(status: "completed", score_percent: 0, completed_at: Time.current)
    sign_in_as @student

    answer @first, right(@first)

    assert_select "turbo-stream[action=append][target=toasts]", text: /#{I18n.t("#{ERRORS}.base.session_closed")}/
    assert_equal 0, Orm::QuestionAttempt.count
  end

  test "la session d'un autre élève : 403, rien n'est écrit" do
    sign_in_as create_student

    answer @first, right(@first)

    assert_response :forbidden
    assert_equal 0, Orm::QuestionAttempt.count
  end

  test "un enseignant ne répond pas : 403" do
    sign_in_as create_teacher

    answer @first, right(@first)

    assert_response :forbidden
  end

  test "session inconnue : 404" do
    sign_in_as @student

    post exercise_session_attempts_path("inconnu000000"), headers: TURBO,
                                                          params: { attempt: { question_id: @first.id, answer_ids: [ right(@first).id ] } }

    assert_response :not_found
  end

  test "repli HTML : verdict en flash et retour à la session ; erreur en page complète ; doublon en alerte" do
    sign_in_as @student

    answer @first, right(@first), headers: {}
    assert_redirected_to exercise_session_path(@session.public_id)
    assert_equal I18n.t("assessment.question_attempts.create.success"), flash[:notice]

    answer @second, wrong(@second), headers: {}
    assert_equal I18n.t("assessment.question_attempts.create.error"), flash[:notice]

    answer @first, right(@first), headers: {}
    assert_redirected_to exercise_session_path(@session.public_id)
    assert_equal I18n.t("#{ERRORS}.base.session_closed"), flash[:alert]
  end

  test "repli HTML d'une réponse vide : la page de session en 422, avec l'erreur" do
    sign_in_as @student

    post exercise_session_attempts_path(@session.public_id), params: { attempt: { question_id: @first.id } }

    assert_response :unprocessable_entity
    assert_select "h1", text: "Méiose"
    assert_select "#attempt-errors", text: I18n.t("#{ERRORS}.answer_ids.blank")
  end
end

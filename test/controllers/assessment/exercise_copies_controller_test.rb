require "test_helper"

# AS-07, AS-09 à AS-13 (ADR-0112, UDR-0138 §3.3) : l'élève rend sa copie d'un seul envoi. 303 vers le résultat, 422 qui
# réaffiche ses réponses, retrait de l'exercice vers la leçon, copie d'un autre élève refusée. Une question laissée vide
# compte fausse et « sans réponse ». Les entrées hostiles sont refusées sans rien écrire.
class Assessment::ExerciseCopiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @exercise = create_exercise(title: "Méiose", questions: 2)
    @course = @exercise.essential.course
    @student = create_student_for(@course)
    @first, @second = @exercise.questions.order(:position).to_a
    @session = create_exercise_session(student: @student, exercise: @exercise)
  end

  def right(question) = question.answers.where(correct: true).order(:id).pluck(:id)
  def wrong(question) = question.answers.where(correct: false).order(:id).pick(:id)

  # La page poste des indices d'affichage, jamais des identifiants (ADR-0091 §4.4) : ceux de la session pour ces propositions.
  def displayed(question, ids, session: @session)
    shuffled = Entities::Assessment::AnswerShuffle.for(session_id: session.id, question_id: question.id, ids: question.answers.pluck(:id))
    Array(ids).map { shuffled.index(it).to_s }
  end

  def copy(answers, session: @session)
    post exercise_session_copy_path(session.public_id), params: { copy: { answers: } }
  end

  def pick(question, ids, session: @session) = { question.id.to_s => { display_order: displayed(question, ids, session:) } }

  test "une copie complète : 303 vers le résultat, la session close, la note et les tentatives écrites" do
    sign_in_as @student

    copy pick(@first, right(@first)).merge(pick(@second, wrong(@second)))

    assert_redirected_to exercise_session_result_path(@session.public_id)
    assert_equal [ "completed", 50, 2 ], @session.reload.then { [ it.status, it.score_percent, it.answered_count ] }
    assert_equal [ [ @first.id, true, false ], [ @second.id, false, false ] ],
                 Orm::QuestionAttempt.order(:question_id).pluck(:question_id, :correct, :unanswered)
  end

  test "une question laissée vide compte fausse et « Sans réponse » au résultat" do
    sign_in_as @student

    copy pick(@first, right(@first)).merge(@second.id.to_s => { display_order: [] })
    follow_redirect!

    attempt = Orm::QuestionAttempt.find_by!(question: @second)
    assert_equal [ false, true, [] ], [ attempt.correct, attempt.unanswered, attempt.selected_answer_ids ]
    assert_select "#question_review_#{@second.id}", text: /#{I18n.t("assessment.session_results.show.unanswered")}/
    assert_select "#question_review_#{@first.id}", text: /#{I18n.t("assessment.session_results.show.correct")}/
  end

  test "une copie entièrement vide est rendue : tout est sans réponse, 0/20" do
    sign_in_as @student

    post exercise_session_copy_path(@session.public_id)

    assert_redirected_to exercise_session_result_path(@session.public_id)
    assert_equal [ 0, 2 ], [ @session.reload.score_percent, Orm::QuestionAttempt.where(unanswered: true).count ]
  end

  test "rendre deux fois : la seconde ne réécrit rien et mène au résultat" do
    sign_in_as @student
    copy pick(@first, right(@first))

    assert_no_difference -> { Orm::QuestionAttempt.count } do
      copy pick(@first, wrong(@first))
    end

    assert_redirected_to exercise_session_result_path(@session.public_id)
    assert_equal 50, @session.reload.score_percent
  end

  test "une saisie invalide : 422, la copie rouverte avec ses réponses et le message de la question, rien d'écrit" do
    sign_in_as @student
    ids = [ wrong(@first), right(@first).first ]

    copy pick(@first, ids).merge(pick(@second, wrong(@second)))

    assert_response :unprocessable_entity
    assert_select "#copy-errors a[href='#question-1']"
    # CA-18 : la question en erreur est marquée et décrite par son message ; l'autre question n'a ni marque ni message.
    assert_select "#question-1 fieldset[aria-invalid=true][aria-describedby='question-1-error']"
    assert_select "#question-1-error", text: /\S/
    assert_select "#question-2-error", 0
    assert_select "#question-2 input[type=radio][value='#{displayed(@second, wrong(@second)).first}'][checked]"
    assert_equal 0, Orm::QuestionAttempt.count
    assert_equal "started", @session.reload.status
  end

  test "une saisie invalide à côté d'une réponse qui n'est pas une table : 422, cette réponse rouverte vide" do
    sign_in_as @student

    copy({ @first.id.to_s => "x" }.merge(pick(@second, [ wrong(@second), right(@second).first ])))

    assert_response :unprocessable_entity
    assert_select "#question-1 input[checked]", 0
    assert_equal 0, Orm::QuestionAttempt.count
  end

  # Entrées hostiles : chacune est refusée (422) sans écrire, la session reste ouverte.
  test "entrées hostiles : proposition d'une autre question, clé inconnue, trop de réponses, texte à octet nul" do
    other = create_exercise(questions: 1).questions.first
    sign_in_as @student
    hostile = [
      { @first.id.to_s => { display_order: [ "7" ] } },
      { @first.id.to_s => { display_order: [ "0", "0" ] } },
      { @first.id.to_s => { display_order: [ other.answers.pick(:id).to_s ] } },
      pick(@first, right(@first)).merge("999999" => { display_order: [ "1" ] }),
      (1..101).to_h { [ it.to_s, { display_order: [ "1" ] } ] },
      { @first.id.to_s => { response_text: "a\0b" } },
      { "pas-un-id" => { display_order: [ "1" ] } }
    ]

    hostile.each do |answers|
      copy answers

      assert_response :unprocessable_entity
      assert_equal [ 0, "started" ], [ Orm::QuestionAttempt.count, @session.reload.status ]
    end
  end

  # N1 : sur un texte à trous, l'octet nul et les 201 caractères sont refusés en HTTP, avec le message de la question.
  test "menace : un texte à trous avec un octet nul ou de 201 caractères : 422, message de la question, rien d'écrit" do
    blank = create_kind_question(exercise: @exercise, question_type: "fill_blank", answers: [ "Paris" ], content: "La capitale est ___.")
    number = @exercise.questions.order(:position).to_a.index(blank) + 1
    sign_in_as @student

    [ "a\0b", "x" * 201 ].each do |text|
      copy({ blank.id.to_s => { response_text: text } })

      assert_response :unprocessable_entity
      assert_select "#question-#{number}-error", text: /\S/
      assert_equal [ 0, "started" ], [ Orm::QuestionAttempt.count, @session.reload.status ]
    end
  end

  # Décision du porteur : la copie garde les tentatives faites par l'ancien mode et ne note que les questions sans tentative.
  test "une tentative déjà en base (ancien mode) : la copie la garde, note le reste, clôt, et mène au résultat" do
    Orm::QuestionAttempt.create!(exercise_session_id: @session.id, question_id: @first.id, selected_answer_ids: right(@first),
                                 correct: true, answered_at: Time.current)
    sign_in_as @student

    copy pick(@first, wrong(@first)).merge(pick(@second, right(@second)))

    assert_redirected_to exercise_session_result_path(@session.public_id)
    assert_equal [ "completed", 100 ], @session.reload.then { [ it.status, it.score_percent ] }
    assert_equal [ [ @first.id, true ], [ @second.id, true ] ], Orm::QuestionAttempt.order(:question_id).pluck(:question_id, :correct)
    follow_redirect!
    assert_no_match(/#{I18n.t("assessment.exercise_sessions.show.abandoned")}/, response.body)
  end

  test "des paramètres qui ne sont pas des tables : traités comme une copie vide, jamais 500" do
    sign_in_as @student

    post exercise_session_copy_path(@session.public_id), params: { copy: "x" }
    assert_redirected_to exercise_session_result_path(@session.public_id)
  end

  test "la copie d'un autre élève : 403, rien d'écrit ; inconnue : 404 ; enseignant : 403 ; sans connexion : connexion" do
    sign_in_as create_student_for(@course)
    copy pick(@first, right(@first))
    assert_response :forbidden
    assert_equal 0, Orm::QuestionAttempt.count

    copy pick(@first, right(@first)), session: Struct.new(:public_id).new("inconnu000000")
    assert_response :not_found

    sign_in_as create_teacher
    copy pick(@first, right(@first))
    assert_response :forbidden

    sign_out
    copy pick(@first, right(@first))
    assert_redirected_to new_session_path
  end

  test "copie abandonnée (Recommencer dans un autre onglet) : retour à l'exercice avec l'alerte" do
    @session.update!(status: "abandoned")
    sign_in_as @student

    copy pick(@first, right(@first))

    assert_redirected_to exercise_path(@exercise.public_id)
    assert_equal I18n.t("assessment.exercise_sessions.show.abandoned"), flash[:alert]
    assert_equal 0, Orm::QuestionAttempt.count
  end

  test "exercice retiré pendant la copie : retour à la leçon, à la notion, avec l'alerte" do
    @exercise.update!(status: "archived")
    sign_in_as @student

    copy pick(@first, right(@first))

    assert_redirected_to course_path(@course.slug, anchor: "notion-#{@exercise.essential.slug}")
    assert_equal I18n.t("assessment.exercise_copies.create.archived"), flash[:alert]
    assert_equal 0, Orm::QuestionAttempt.count
  end

  test "exercice retiré, de toute la leçon : retour à la leçon, ancre « toute-la-lecon »" do
    lesson = create_lesson_wide_exercise(course: @course)
    session = create_exercise_session(student: @student, exercise: lesson)
    lesson.update!(status: "archived")
    sign_in_as @student

    copy({}, session:)

    assert_redirected_to course_path(@course.slug, anchor: "toute-la-lecon")
  end

  test "un élève hors niveau ne rend pas sa propre copie : 404" do
    other_level = create_student_for(create_course(level: create_level(name: "6e")))
    session = create_exercise_session(student: other_level, exercise: @exercise)
    sign_in_as other_level

    copy pick(@first, right(@first), session: session), session: session

    assert_response :not_found
    assert_equal 0, Orm::QuestionAttempt.count
  end

  test "un élève hors niveau : exercice de toute la leçon, la copie et le résultat sont en 404" do
    lesson = create_lesson_wide_exercise(course: @course, questions: 1)
    other_level = create_student_for(create_course(level: create_level(name: "6e")))
    session = create_exercise_session(student: other_level, exercise: lesson)
    sign_in_as other_level

    copy({}, session:)
    assert_response :not_found
    get exercise_session_result_path(session.public_id)
    assert_response :not_found
    assert_equal 0, Orm::QuestionAttempt.count
  end

  # CA-14 : un exercice de toute la leçon se joue de bout en bout, sans notion ni lacune.
  test "exercice de toute la leçon : feuille, copie, envoi, résultat, sans « Notion à revoir »" do
    lesson = create_lesson_wide_exercise(course: @course, title: "Bilan du chapitre", questions: 2)
    first, second = lesson.questions.order(:position).to_a
    sign_in_as @student

    get exercise_path(lesson.public_id)
    assert_response :success
    assert_select "#exercise-sheet"

    post exercise_sessions_path(lesson.public_id)
    session = Orm::ExerciseSession.find_by!(exercise: lesson)
    follow_redirect!
    assert_response :success
    assert_select "form#copy-form"

    copy pick(first, wrong(first), session: session).merge(pick(second, wrong(second), session: session)), session: session
    assert_redirected_to exercise_session_result_path(session.public_id)
    follow_redirect!

    assert_response :success
    assert_select "#session_gap_outcome", 0
    assert_select "a[href='#{course_path(@course.slug, anchor: "toute-la-lecon")}']", text: I18n.t("assessment.session_results.show.back_to_lesson")
    assert_equal 0, Orm::KnowledgeGap.count
  end

  # CA-23 : la copie d'un exercice de notion échoué ouvre « Notion à revoir ».
  test "un exercice de notion échoué ouvre la lacune, visible au résultat" do
    sign_in_as @student

    copy pick(@first, wrong(@first)).merge(pick(@second, wrong(@second)))
    follow_redirect!

    assert_equal [ 1, @exercise.essential_id, @student.id ],
                 [ Orm::KnowledgeGap.count, Orm::KnowledgeGap.sole.essential_id, Orm::KnowledgeGap.sole.student_id ]
    assert_select "#session_gap_outcome a[href='#{course_path(@course.slug, anchor: "notion-#{@exercise.essential.slug}")}']"
  end
end

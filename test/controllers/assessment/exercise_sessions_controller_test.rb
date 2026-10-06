require "test_helper"

# AS-07, AS-08 (UDR-0022) : l'élève démarre un exercice publié, assigné ou non, reprend sa session ou la recommence ;
# un brouillon n'existe pas pour lui (404) ; un enseignant ne démarre rien (403). La page de session ne montre que la
# prochaine question, sans aucune correction.
class Assessment::ExerciseSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @exercise = create_exercise(title: "Méiose", questions: 2)
    course = @exercise.essential.course
    # UDR-0013, amendement du 2026-10-01 : l'élève est d'une classe du niveau du cours de l'exercice.
    @classroom = create_classroom(level: course.level, series: course.series)
    @student = create_student(classroom: @classroom)
  end

  def scope = "assessment.exercise_sessions"

  test "démarrer un exercice non assigné : une session ouverte, figée à 2 questions, puis la première question" do
    sign_in_as @student

    assert_difference -> { Orm::ExerciseSession.count }, 1 do
      post exercise_sessions_path(@exercise.public_id)
    end

    session = Orm::ExerciseSession.sole
    assert_redirected_to exercise_session_path(session.public_id)
    assert_equal [ @student.id, "started", 2, nil, "standard" ],
                 [ session.student_id, session.status, session.question_count, session.classroom_assignment_id, session.kind ]

    follow_redirect!
    assert_response :success
    assert_select "h1", text: "Méiose"
    # UDR-0022, amendement du 2026-10-02 : l'avancement n'est dit qu'une fois, par « Question n sur T » ; la barre est seule (R6).
    assert_select "#progress_bar > *", 1
    assert_select "#progress_bar > progress[value='0'][max='100'][aria-label=?]", I18n.t("#{scope}.progress_bar.label"),
                  text: I18n.t("#{scope}.progress_bar.percent", percent: 0)
    assert_select "turbo-frame#question #question-card", text: /#{I18n.t("#{scope}.question_card.number", number: 1, total: 2)}/
    # Une question à choix unique : pas de consigne, les boutons radio la portent (R4).
    assert_select "#attempt-form fieldset > p", 0
    assert_select "#attempt-form[action='#{exercise_session_attempts_path(session.public_id)}'] input[type=radio]", 4
    assert_select "#attempt-form input[type=hidden][name='attempt[question_id]'][value='#{@exercise.questions.order(:position).first.id}']"
    assert_select "a[href='#{exercise_path(@exercise.public_id)}']", text: /#{I18n.t("#{scope}.show.quit")}/
  end

  test "une question à plusieurs réponses : « Coche N propositions. », sans badge qui le redit" do
    @exercise.questions.order(:position).first.update!(question_type: "multiple_correct_2")
    session = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student

    get exercise_session_path(session.public_id)

    assert_response :success
    assert_select "#attempt-form fieldset > p", text: "Coche 2 propositions."
    assert_select "#attempt-form input[type=checkbox]", 4
    assert_select "#question-card", text: /Plusieurs propositions correctes/, count: 0
  end

  test "un exercice assigné à la classe : la session est rattachée à l'assignation" do
    assignment = create_assignment(classroom: @classroom, assignable: @exercise, by: create_teacher(classrooms: [ @classroom ]))
    sign_in_as @student

    post exercise_sessions_path(@exercise.public_id)

    assert_equal assignment.id, Orm::ExerciseSession.sole.classroom_assignment_id
  end

  test "Reprendre ouvre la session en cours à la question suivante ; Recommencer l'abandonne et en ouvre une autre" do
    open = create_exercise_session(student: @student, exercise: @exercise)
    first, second = @exercise.questions.order(:position).to_a
    create_attempt(session: open, question: first)
    sign_in_as @student

    post exercise_sessions_path(@exercise.public_id)
    assert_redirected_to exercise_session_path(open.public_id)
    follow_redirect!
    assert_select "#attempt-form input[name='attempt[question_id]'][value='#{second.id}']"

    post exercise_sessions_path(@exercise.public_id), params: { restart: "true" }
    fresh = Orm::ExerciseSession.find_by!(status: "started")
    assert_redirected_to exercise_session_path(fresh.public_id)
    assert_equal "abandoned", open.reload.status
    assert_not_equal open.id, fresh.id
  end

  test "brouillon, ou publié dans une fiche en brouillon : 404 et aucune session" do
    draft = create_exercise(status: "draft")
    hidden = create_exercise(essential: create_essential(status: "draft"))
    sign_in_as @student

    post exercise_sessions_path(draft.public_id)
    assert_response :not_found
    post exercise_sessions_path(hidden.public_id)
    assert_response :not_found
    post exercise_sessions_path("inconnu000000")
    assert_response :not_found
    assert_equal 0, Orm::ExerciseSession.count
  end

  test "un enseignant ne démarre pas de session et n'ouvre pas celle d'un élève : 403" do
    session = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as create_teacher(classrooms: [ @classroom ])

    post exercise_sessions_path(@exercise.public_id)
    assert_response :forbidden
    get exercise_session_path(session.public_id)
    assert_response :forbidden
    assert_equal 1, Orm::ExerciseSession.count
  end

  test "la session d'un autre élève : 403, sans rien en montrer" do
    session = create_exercise_session(exercise: @exercise)
    sign_in_as @student

    get exercise_session_path(session.public_id)

    assert_response :forbidden
    assert_no_match(/Méiose/, response.body)
  end

  test "session inconnue : 404" do
    sign_in_as @student

    get exercise_session_path("inconnu000000")

    assert_response :not_found
  end

  test "une session terminée mène au résultat, une session abandonnée à l'exercice" do
    completed = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 50)
    abandoned = create_exercise_session(student: @student, exercise: @exercise, status: "abandoned")
    sign_in_as @student

    get exercise_session_path(completed.public_id)
    assert_redirected_to exercise_session_result_path(completed.public_id)

    get exercise_session_path(abandoned.public_id)
    assert_redirected_to exercise_path(@exercise.public_id)
    assert_equal I18n.t("#{scope}.show.abandoned"), flash[:alert]
  end

  test "le HTML d'une question non tentée ne contient aucune marque de proposition correcte (AS-10)" do
    session = create_exercise_session(student: @student, exercise: @exercise)
    correct_ids = Orm::Answer.where(question: @exercise.questions, correct: true).pluck(:id)
    sign_in_as @student

    get exercise_session_path(session.public_id)

    assert_response :success
    assert_no_match(/correct/i, response.body.scan(/<turbo-frame id="question".*<\/turbo-frame>/m).join)
    # La question affichée n'est pas forcément celle dont la base rend d'abord la bonne réponse : une seule des bonnes
    # réponses de l'exercice est dans le formulaire, sans marque qui la distingue.
    assert_equal 1, correct_ids.count { |id| css_select("#attempt-form input[value='#{id}']").any? }
    assert_select "#attempt-form [data-correct], #attempt-form .correct", 0
  end

  test "sans connexion : vers la page de connexion" do
    post exercise_sessions_path(@exercise.public_id)

    assert_redirected_to new_session_path
  end
end

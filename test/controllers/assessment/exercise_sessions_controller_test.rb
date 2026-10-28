require "test_helper"

# AS-07, AS-08 (UDR-0022) : l'élève démarre un exercice publié, assigné ou non, reprend sa session ou la recommence ;
# un brouillon n'existe pas pour lui (404) ; un enseignant ne démarre rien (403). La page de session ne montre que la
# copie entière, sans aucune correction (UDR-0138).
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
    # UDR-0138 §3.2 : la copie montre le sujet repliable, le compteur et toutes les questions dans un seul formulaire.
    assert_select "#copy-counter", text: /0.*2/
    assert_select "details#copy-statement"
    assert_select "form#copy-form[action='#{exercise_session_copy_path(session.public_id)}'] fieldset", 2
    assert_select "form#copy-form input[type=radio]", 8
    assert_select "form#copy-form button[type=submit]", text: I18n.t("#{scope}.show.submit")
    assert_select "dialog#copy-confirm"
    # CA-01 (UDR-0140) : un seul bouton « Vérifier ma copie », précédé de sa phrase d'avertissement ; ni « Rendre ma copie », ni durée.
    assert_select "form#copy-form p", text: I18n.t("#{scope}.show.lock_warning")
    assert_no_match(/Rendre ma copie|Vérifier les réponses courtes|minutes?\b/i, css_select("form#copy-form").to_s.sub(/<dialog.*<\/dialog>/m, ""))
  end

  test "une question à plusieurs réponses : « Coche N propositions. », sans badge qui le redit" do
    @exercise.questions.order(:position).first.update!(question_type: "multiple_correct_2")
    session = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student

    get exercise_session_path(session.public_id)

    assert_response :success
    assert_select "#question-1 fieldset p", text: "Coche 2 propositions."
    assert_select "#question-1 input[type=checkbox]", 4
    assert_select "#question-2 input[type=radio]", 4
  end

  test "un exercice assigné à la classe : la session est rattachée à l'assignation" do
    assignment = create_assignment(classroom: @classroom, assignable: @exercise, by: create_teacher(classrooms: [ @classroom ]))
    sign_in_as @student

    post exercise_sessions_path(@exercise.public_id)

    assert_equal assignment.id, Orm::ExerciseSession.sole.classroom_assignment_id
  end

  test "Reprendre ouvre la copie en cours ; Recommencer l'abandonne et en ouvre une autre" do
    open = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student

    post exercise_sessions_path(@exercise.public_id)
    assert_redirected_to exercise_session_path(open.public_id)

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

  # CA-14 : la copie ne contient aucune marque de proposition correcte, aucune explication, aucun identifiant de bonne réponse.
  test "le HTML de la copie ne contient aucune marque de correction (CA-14, AS-10)" do
    # Des ids de réponse qu'aucun indice d'affichage ne peut valoir : sans cela, un id petit passe pour un indice.
    Orm::Answer.connection.execute("ALTER SEQUENCE #{Orm::Answer.sequence_name} RESTART WITH 914273001")
    exercise = create_exercise(title: "Ids distincts", questions: 2)
    exercise.questions.first.update!(explanation: "La méiose compte deux divisions.")
    session = create_exercise_session(student: create_student_for(exercise.essential.course).tap { sign_in_as it }, exercise:)

    get exercise_session_path(session.public_id)

    assert_response :success
    assert_no_match(/correct|La méiose compte deux divisions/i, response.body[/<form id="copy-form".*<\/form>/m].to_s)
    # Tout le corps de la page, sauf les icônes : l'explication n'est nulle part.
    assert_no_match(/La méiose compte deux divisions/, response.body.gsub(%r{<svg.*?</svg>}m, ""))
    assert_select "#copy-form [data-correct], #copy-form .correct", 0
    assert_select "#copy-form input[name$='[display_order][]']", 8
    # ADR-0091 §4.4 : une proposition montrée porte son indice d'affichage, jamais son identifiant (qui trahit l'ordre de saisie).
    answer_ids = exercise.questions.flat_map { it.answers.pluck(:id) }.map(&:to_s)
    assert_empty answer_ids & css_select("#copy-form input[name$='[display_order][]']").map { it["value"] }
    assert_equal [ "0", "1", "2", "3" ], css_select("#copy-form #question-1 input[name$='[display_order][]']").map { it["value"] }.sort
  end

  # CA-14 : la copie d'un exercice de toute la leçon s'ouvre pour l'élève du niveau (200), jamais pour un autre niveau (404).
  test "exercice de toute la leçon : la copie s'ouvre au bon niveau (200), 404 à un autre niveau" do
    lesson = create_lesson_wide_exercise(course: @exercise.essential.course, title: "Bilan", questions: 2)
    session = create_exercise_session(student: @student, exercise: lesson)
    sign_in_as @student

    get exercise_session_path(session.public_id)
    assert_response :success
    assert_select "form#copy-form fieldset", 2

    elsewhere = create_student_for(create_course(level: create_level(name: "6e")))
    foreign = create_exercise_session(student: elsewhere, exercise: lesson)
    sign_in_as elsewhere
    get exercise_session_path(foreign.public_id)
    assert_response :not_found
  end

  test "sans connexion : vers la page de connexion" do
    post exercise_sessions_path(@exercise.public_id)

    assert_redirected_to new_session_path
  end

  # ADR-0105 §4.4, UDR-0129 §3.4: the student reads the image of a question above its statement, lazily, at its dimensions.
  test "l'image d'une question se lit au-dessus de l'énoncé, chargée à la demande et à ses dimensions" do
    second = @exercise.questions.order(:position).second
    image = create_question_image(question: second, alt: "Une pile reliée à une lampe")
    session = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student

    get exercise_session_path(session.public_id)

    assert_response :success
    assert_select "#question-2 img[src=?][alt=?][loading=lazy][width=?][height=?]", question_image_path(image.public_id),
                  "Une pile reliée à une lampe", image.width.to_s, image.height.to_s
    assert_select "#question-1 img", 0
    html = response.body
    assert_operator html.index(%(id="question-2")), :<, html.index(question_image_path(image.public_id))
    assert_operator html.index(question_image_path(image.public_id)), :<, html.index(CGI.escapeHTML(second.content)),
                    "l'image précède l'énoncé"
  end
end

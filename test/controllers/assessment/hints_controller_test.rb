require "test_helper"

# CA-14, CA-15 (ADR-XXXX questions à plusieurs cases §4, UDR-XXXX §3.8) : l'indice d'une question ne se lit qu'une fois son ouverture
# enregistrée. Avant le POST, son texte n'est nulle part dans la page. Copie rendue, copie d'un autre élève, question sans indice : 404.
class Assessment::HintsControllerTest < ActionDispatch::IntegrationTest
  HINT = "Pense au rapport de proportionnalité."

  setup do
    @exercise = create_exercise(title: "Thalès", questions: 2)
    @course = @exercise.essential.course
    @student = create_student_for(@course)
    @first, @second = @exercise.questions.order(:position).to_a
    @second.update!(hint: HINT)
    @session = create_exercise_session(student: @student, exercise: @exercise)
  end

  def open_hint(question = @second, session: @session, **options)
    post exercise_session_hints_path(session.public_id), params: { question_id: question.id }, **options
  end

  test "avant le POST : le bouton « Indice » est dans la copie, le texte de l'indice nulle part" do
    sign_in_as @student

    get exercise_session_path(@session.public_id)

    assert_response :success
    # Le formulaire est hors de la copie (pas de formulaire imbriqué) ; le bouton, dans le frame, le désigne par form=.
    assert_select "form#hint-form-#{@second.id}[action=?]", exercise_session_hints_path(@session.public_id) do
      assert_select "input[type=hidden][name=question_id][value=?]", @second.id.to_s
    end
    assert_select "form#copy-form form", count: 0
    assert_select "turbo-frame#hint_#{@second.id} button[type=submit][form=?]", "hint-form-#{@second.id}",
                  text: /#{I18n.t("assessment.exercise_sessions.show.hint_button")}/
    assert_select "turbo-frame#hint_#{@first.id}", count: 0
    assert_no_match HINT, response.body
    assert_includes response.body, I18n.t("assessment.exercise_sessions.show.hint_notice")
  end

  test "le POST en Turbo Stream remplace hint_<id> par le texte, et l'ouverture est enregistrée une seule fois" do
    sign_in_as @student

    2.times { open_hint(headers: { "Accept" => "text/vnd.turbo-stream.html" }) }

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_select "turbo-stream[action=replace][target=hint_#{@second.id}]"
    assert_includes response.body, HINT
    assert_select "button", count: 0
    assert_equal [ @second.id ], @session.reload.hinted_question_ids
  end

  test "sans JavaScript : redirection vers la copie à l'ancre de la question, l'indice ouvert" do
    sign_in_as @student

    open_hint

    assert_redirected_to exercise_session_path(@session.public_id, anchor: "question-2")
    follow_redirect!
    assert_includes response.body, HINT
    assert_select "turbo-frame#hint_#{@second.id}", count: 0
    assert_select "form#hint-form-#{@second.id}", count: 0
  end

  test "ouvrir un indice ne change pas la note de la copie" do
    sign_in_as @student

    assert_no_difference [ "Orm::QuestionAttempt.count", "Orm::ExerciseSession.where(status: 'completed').count" ] do
      open_hint
    end

    assert_redirected_to exercise_session_path(@session.public_id, anchor: "question-2")
    assert_equal [ "started", nil, [ @second.id ] ], @session.reload.then { [ it.status, it.score_percent, it.hinted_question_ids ] }
  end

  test "CA-15 : une copie rendue : 404, rien d'enregistré" do
    done = create_exercise_session(student: @student, exercise: @exercise, status: "completed")
    sign_in_as @student

    open_hint(session: done)

    assert_response :not_found
    assert_empty done.reload.hinted_question_ids
    assert_not_includes response.body, HINT
  end

  test "CA-15 : la copie d'un autre élève : 404, rien d'enregistré" do
    sign_in_as create_student_for(@course)

    open_hint

    assert_response :not_found
    assert_empty @session.reload.hinted_question_ids
    assert_not_includes response.body, HINT
  end

  test "une question sans indice, d'un autre exercice ou inexistante : 404, rien d'enregistré" do
    other = create_exercise(questions: 1).questions.first.tap { it.update!(hint: "Ailleurs.") }
    sign_in_as @student

    [ @first, other ].each do |question|
      open_hint(question)
      assert_response :not_found, "question #{question.id}"
    end
    post exercise_session_hints_path(@session.public_id), params: { question_id: 0 }
    assert_response :not_found
    post exercise_session_hints_path(@session.public_id)
    assert_response :not_found
    assert_empty @session.reload.hinted_question_ids
  end

  test "CA-15 : une copie abandonnée : 404, rien d'enregistré" do
    abandoned = create_exercise_session(student: @student, exercise: @exercise, status: "abandoned")
    sign_in_as @student

    open_hint(session: abandoned)

    assert_response :not_found
    assert_empty abandoned.reload.hinted_question_ids
    assert_not_includes response.body, HINT
  end

  test "un enseignant ne peut pas ouvrir l'indice de la copie d'un élève : refusé par le rôle (403), rien d'enregistré" do
    sign_in_as create_teacher(classrooms: [])

    open_hint

    assert_response :forbidden
    assert_empty @session.reload.hinted_question_ids
    assert_not_includes response.body, HINT
  end

  test "sans rang de question lisible dans la copie, la redirection n'a pas d'ancre" do
    sign_in_as @student
    unreadable = Struct.new(:questions).new([])
    original = Queries::Assessment::SessionPlayQuery.instance_method(:copy)
    Queries::Assessment::SessionPlayQuery.define_method(:copy) { |**| unreadable }

    begin
      open_hint
    ensure
      Queries::Assessment::SessionPlayQuery.define_method(:copy, original)
    end

    assert_redirected_to exercise_session_path(@session.public_id)
    assert_equal [ @second.id ], @session.reload.hinted_question_ids
  end

  test "la copie reste hors d'atteinte d'un visiteur déconnecté" do
    open_hint

    assert_response :redirect
    assert_empty @session.reload.hinted_question_ids
  end
end

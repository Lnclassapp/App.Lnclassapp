require "test_helper"

# CA-14 (ADR-0120 questions à plusieurs cases §4, UDR-0147 §3.8, §3.9) : l'élève ouvre l'indice de la question 2, le lit, rend sa copie ;
# la note est celle d'une copie sans indice, et « Indice ouvert » se lit sur la question 2 seulement, pour l'élève comme pour l'enseignant.
class Assessment::HintInCopyTest < ActionDispatch::IntegrationTest
  HINT = "Pense au rapport de proportionnalité."

  setup do
    @essential = create_essential(name: "Thalès")
    @classroom = create_classroom(level: @essential.course.level)
    @student = create_student(classroom: @classroom)
    @exercise = create_exercise(essential: @essential, title: "Thalès", questions: 2)
    @first, @second = @exercise.questions.order(:position).to_a
    @second.update!(hint: HINT)
  end

  def displayed(question, session)
    ids = question.answers.pluck(:id)
    shuffled = Entities::Assessment::AnswerShuffle.for(session_id: session.id, question_id: question.id, ids:)
    [ shuffled.index(question.answers.find_by!(correct: true).id).to_s ]
  end

  # Une copie juste sur les deux questions, avec ou sans indice ouvert : → la note.
  def graded_copy(with_hint:)
    student = create_student(classroom: @classroom)
    session = create_exercise_session(student:, exercise: @exercise)
    sign_in_as student
    post exercise_session_hints_path(session.public_id), params: { question_id: @second.id } if with_hint
    post exercise_session_copy_path(session.public_id),
         params: { copy: { answers: [ @first, @second ].to_h { [ it.id.to_s, { display_order: displayed(it, session) } ] } } }
    sign_out
    session.reload
  end

  test "la note d'une copie avec indice est celle d'une copie sans indice, et le résultat marque la question 2 seulement" do
    plain = graded_copy(with_hint: false)
    hinted = graded_copy(with_hint: true)

    assert_equal [ plain.score_percent, plain.status ], [ hinted.score_percent, hinted.status ]
    assert_equal [ @second.id ], hinted.hinted_question_ids
    assert_empty plain.hinted_question_ids

    sign_in_as hinted.student
    get exercise_session_result_path(hinted.public_id)
    assert_select "#question_review_#{@second.id}", text: /#{I18n.t("assessment.session_results.question_review.hint_opened")}/
    assert_select "#question_review_#{@first.id}", text: /#{I18n.t("assessment.session_results.question_review.hint_opened")}/, count: 0
  end

  test "l'enseignant de la classe et l'équipe lisent « Indice ouvert » sur la question 2 seulement" do
    hinted = graded_copy(with_hint: true)

    [ create_teacher(classrooms: [ @classroom ]), create_team_member ].each do |reader|
      sign_in_as reader
      get exercise_session_result_path(hinted.public_id)

      assert_response :success
      badge = I18n.t("assessment.session_results.question_review.hint_opened")
      assert_select "#question_review_#{@second.id}", text: /#{badge}/
      assert_select "#question_review_#{@first.id}", text: /#{badge}/, count: 0
      sign_out
    end
  end

  test "une copie rechargée montre l'indice déjà ouvert, et pas celui d'une question fermée" do
    other = @first.tap { it.update!(hint: "Un autre indice.") }
    session = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student
    post exercise_session_hints_path(session.public_id), params: { question_id: @second.id }

    get exercise_session_path(session.public_id)

    assert_includes response.body, HINT
    assert_not_includes response.body, other.hint
    assert_select "turbo-frame#hint_#{other.id} button[form=?]", "hint-form-#{other.id}"
  end
end

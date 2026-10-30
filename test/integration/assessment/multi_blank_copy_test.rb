require "test_helper"

# CA-11, ADR questions à plusieurs cases §4 : une question chiffrée à 2 cases valant 2 points, juste sur la 1re et fausse sur
# la 2nde, compte 1 point sur 2 ; la tentative est fausse ; la page de résultat dit « Juste » et « À revoir » par case.
class Assessment::MultiBlankCopyTest < ActionDispatch::IntegrationTest
  def two_blank_exercise
    exercise = create_exercise(title: "Thalès", questions: 0)
    numeric = exercise.questions.create!(position: 1, content: "AN (cm) = ___  MN (cm) = ___", question_type: "numeric", points: 2)
    [ "3", "4" ].each_with_index { |value, blank| numeric.answers.create!(position: blank + 1, content: value, correct: true, blank:) }
    single = exercise.questions.create!(position: 2, content: "Capitale ___", question_type: "fill_blank", points: 1)
    single.answers.create!(position: 1, content: "Abidjan", correct: true)
    [ exercise, numeric, single ]
  end

  test "2 cases sur 2 points, une juste : 1 point sur 3, la tentative fausse, les verdicts par case" do
    exercise, numeric, single = two_blank_exercise
    student = create_student_for(exercise.essential.course)
    session = create_exercise_session(student:, exercise:)
    sign_in_as student

    post exercise_session_copy_path(session.public_id), params: { copy: { answers: {
      numeric.id.to_s => { blanks: { "0" => "3", "1" => "5" } }, single.id.to_s => { response_text: "Abidjan" }
    } } }

    assert_redirected_to exercise_session_result_path(session.public_id)
    attempt = Orm::QuestionAttempt.find_by!(exercise_session: session, question: numeric)
    assert_equal [ false, [ "3", "5" ], [ true, false ] ], [ attempt.correct, attempt.blank_responses, attempt.blank_results ]
    assert_equal [ true, [], [] ], Orm::QuestionAttempt.find_by!(exercise_session: session, question: single).then { [ it.correct, it.blank_responses, it.blank_results ] }
    # (2 × 1/2 + 1 × 1) / 3 points = 2/3 : 66 %
    assert_equal [ "completed", 66 ], session.reload.values_at(:status, :score_percent)

    get exercise_session_result_path(session.public_id)
    assert_response :success
    verdicts = css_select("#question_review_#{numeric.id} [data-blank-verdict]")
    assert_equal [ "correct", "wrong" ], verdicts.map { it["data-blank-verdict"] }
    assert_match(/Juste/, verdicts.first.text)
    assert_match(/À revoir/, verdicts.last.text)
    assert_select "#question_review_#{numeric.id}", text: %r{1 / 2 pt}
  end

  test "une copie à 2 cases et 2 points, juste sur la 1re et fausse sur la 2nde seule : 50 %" do
    exercise = create_exercise(title: "Seule", questions: 0)
    question = exercise.questions.create!(position: 1, content: "___ et ___", question_type: "numeric", points: 2)
    [ "3", "4" ].each_with_index { |value, blank| question.answers.create!(position: blank + 1, content: value, correct: true, blank:) }
    student = create_student_for(exercise.essential.course)
    session = create_exercise_session(student:, exercise:)
    sign_in_as student

    post exercise_session_copy_path(session.public_id), params: { copy: { answers: { question.id.to_s => { blanks: { "0" => "3", "1" => "9" } } } } }

    assert_equal [ "completed", 50 ], session.reload.values_at(:status, :score_percent)
  end

  test "une saisie illisible dans une case refuse la copie entière, rien n'est écrit" do
    exercise, numeric, _single = two_blank_exercise
    student = create_student_for(exercise.essential.course)
    session = create_exercise_session(student:, exercise:)
    sign_in_as student

    post exercise_session_copy_path(session.public_id), params: { copy: { answers: { numeric.id.to_s => { blanks: { "0" => "3", "1" => "x,,y" } } } } }

    assert_response :unprocessable_entity
    assert_equal 0, Orm::QuestionAttempt.where(exercise_session: session).count
    assert_equal "started", session.reload.status
  end

  test "une question à plusieurs cases laissée entièrement vide est sans réponse, fausse" do
    exercise, numeric, single = two_blank_exercise
    student = create_student_for(exercise.essential.course)
    session = create_exercise_session(student:, exercise:)
    sign_in_as student

    post exercise_session_copy_path(session.public_id), params: { copy: { answers: {
      numeric.id.to_s => { blanks: { "0" => "", "1" => " " } }, single.id.to_s => { response_text: "Abidjan" }
    } } }

    assert_redirected_to exercise_session_result_path(session.public_id)
    assert_equal [ true, [], [] ], Orm::QuestionAttempt.find_by!(exercise_session: session, question: numeric).then { [ it.unanswered, it.blank_responses, it.blank_results ] }
    assert_equal 33, session.reload.score_percent
  end

  test "la copie montre un champ par case, dans la phrase, sans aucune bonne réponse" do
    exercise, numeric, single = two_blank_exercise
    student = create_student_for(exercise.essential.course)
    session = create_exercise_session(student:, exercise:)
    sign_in_as student

    get exercise_session_path(session.public_id)

    assert_response :success
    assert_select "input[name='copy[answers][#{numeric.id}][blanks][0]'][inputmode=decimal]"
    assert_select "input[name='copy[answers][#{numeric.id}][blanks][1]']"
    assert_select "input[name='copy[answers][#{numeric.id}][blanks][2]']", 0
    assert_select "input[name='copy[answers][#{single.id}][response_text]']"
    assert_no_match(/value="(3|4)"/, response.body.scan(/<input[^>]*blanks[^>]*>/).join)
  end

  test "une liste à 2 cases : un menu par case, la valeur est l'indice d'affichage, jamais l'identifiant ni la correction" do
    exercise = create_exercise(title: "Liste", questions: 0)
    select = exercise.questions.create!(position: 1, content: "Il ___ puis il ___.", question_type: "select", points: 2)
    [ [ "mange", true, 0 ], [ "dort", false, 0 ], [ "sort", true, 1 ], [ "boit", false, 1 ] ].each_with_index do |(text, correct, blank), rank|
      select.answers.create!(position: rank + 1, content: text, correct:, blank:)
    end
    student = create_student_for(exercise.essential.course)
    session = create_exercise_session(student:, exercise:)
    sign_in_as student

    get exercise_session_path(session.public_id)

    assert_select "select[name='copy[answers][#{select.id}][blanks][0]'] option", 3
    assert_select "select[name='copy[answers][#{select.id}][blanks][1]'] option", 3
    assert_select "select option[value=?]", select.answers.first.id.to_s, count: 0
    assert_no_match(/correct/i, css_select("form#copy-form select").to_s)

    shuffled = Entities::Assessment::AnswerShuffle.for(session_id: session.id, question_id: select.id, ids: select.answers.pluck(:id))
    index_of = ->(text) { shuffled.index(select.answers.find_by!(content: text).id).to_s }
    post exercise_session_copy_path(session.public_id), params: { copy: { answers: { select.id.to_s => { blanks: { "0" => index_of.("mange"), "1" => index_of.("boit") } } } } }

    assert_redirected_to exercise_session_result_path(session.public_id)
    attempt = Orm::QuestionAttempt.find_by!(exercise_session: session)
    assert_equal [ false, %w[mange boit], [ true, false ] ], [ attempt.correct, attempt.blank_responses, attempt.blank_results ]
    assert_equal 50, session.reload.score_percent
  end

  test "une proposition d'une autre case est refusée, et une case en trop aussi" do
    exercise = create_exercise(title: "Liste", questions: 0)
    select = exercise.questions.create!(position: 1, content: "Il ___ puis il ___.", question_type: "select")
    [ [ "mange", true, 0 ], [ "dort", false, 0 ], [ "sort", true, 1 ], [ "boit", false, 1 ] ].each_with_index do |(text, correct, blank), rank|
      select.answers.create!(position: rank + 1, content: text, correct:, blank:)
    end
    student = create_student_for(exercise.essential.course)
    session = create_exercise_session(student:, exercise:)
    sign_in_as student
    shuffled = Entities::Assessment::AnswerShuffle.for(session_id: session.id, question_id: select.id, ids: select.answers.pluck(:id))
    other_case = shuffled.index(select.answers.find_by!(content: "sort").id).to_s

    post exercise_session_copy_path(session.public_id), params: { copy: { answers: { select.id.to_s => { blanks: { "0" => other_case, "1" => "" } } } } }
    assert_response :unprocessable_entity

    post exercise_session_copy_path(session.public_id), params: { copy: { answers: { select.id.to_s => { blanks: { "0" => "0", "1" => "1", "2" => "2" } } } } }
    assert_response :unprocessable_entity
    assert_equal 0, Orm::QuestionAttempt.where(exercise_session: session).count
  end
end

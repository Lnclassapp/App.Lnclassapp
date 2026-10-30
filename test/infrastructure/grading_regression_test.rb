require "test_helper"

# CA-12, ADR questions à plusieurs cases §7 : les notes des copies à une case, recalculées par la règle des cases (Grading.share,
# points_percent en Rational), sont celles de la règle d'avant (points des questions justes sur ceux des questions corrigées).
class GradingRegressionTest < ActiveSupport::TestCase
  POINTS = %w[0.5 1 1.5 2 3 5 20].freeze

  # La règle d'avant les cases, écrite ici telle quelle (ADR-0115 §4) : BigDecimal, un seul arrondi vers le bas.
  def legacy_percent(rows)
    total = rows.sum { |points, _| points }
    return 0 if total.zero?

    (rows.sum { |points, correct| correct ? points : 0 } * 100 / total).floor
  end

  def recomputed_percent(session)
    exercise = Repositories::Assessment::ExerciseRepository.new.find(id: session.exercise_id)
    attempts = Repositories::Assessment::ExerciseSessionRepository.new.attempts(session_id: session.id).to_h { [ it.question_id, it ] }
    Entities::Assessment::Grading.points_percent(
      exercise.questions.select(&:auto_graded?).map { [ it.points, Entities::Assessment::Grading.share(it, attempts[it.id]) ] }
    )
  end

  test "des copies à une case, de types et de barèmes variés : la note recalculée est celle d'avant" do
    random = Random.new(2026)
    40.times do |index|
      exercise = create_exercise(title: "Régression #{index}", questions: 0)
      rows = Array.new(random.rand(1..8)) do |position|
        points = BigDecimal(POINTS.sample(random:))
        question = exercise.questions.create!(position: position + 1, content: "Q#{position} ___", question_type: %w[fill_blank numeric].sample(random:), points:)
        question.answers.create!(position: 1, content: "4", correct: true)
        correct = random.rand < 0.6
        [ question, points, correct ]
      end
      session = create_exercise_session(student: create_student, exercise:)
      rows.each_with_index do |(question, _points, correct), i|
        next if i == 3 # une question sans tentative est fausse

        Orm::QuestionAttempt.create!(exercise_session: session, question:, correct:, selected_answer_ids: [], response_text: (correct ? "4" : "5"), answered_at: Time.current)
      end
      expected = legacy_percent(rows.each_with_index.map { |(_, points, correct), i| [ points, i != 3 && correct ] })

      assert_equal expected, recomputed_percent(session), "exercice #{index} : #{rows.map { |_, p, c| [ p.to_f, c ] }}"
    end
  end

  test "les copies terminées en base : le score enregistré est celui que la règle des cases recalcule" do
    exercise = create_exercise(title: "Mixte", questions: 3)
    session = create_exercise_session(student: create_student, exercise:)
    exercise.questions.order(:position).each_with_index do |question, i|
      create_attempt(session:, question:, correct: i != 1)
    end

    assert_equal 66, recomputed_percent(session)
    assert_equal 66, legacy_percent(exercise.questions.map.with_index { |question, i| [ question.points, i != 1 ] })
  end
end

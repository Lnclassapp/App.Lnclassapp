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

  KINDS = %w[single_choice true_false fill_blank numeric ordering matching].freeze

  # Le vrai CloseExerciseSession, câblé comme à la clôture d'une copie : la note est celle qu'il enregistre, relue sur la session.
  def close!(session)
    sessions = Repositories::Assessment::ExerciseSessionRepository.new
    policy = Policies::Assessment::SubmitAttemptPolicy.new
    close = UseCases::Assessment::CloseExerciseSession.new(
      sessions:, exercises: Repositories::Assessment::ExerciseRepository.new, badges: Repositories::Assessment::BadgeRepository.new,
      gaps: Repositories::Assessment::KnowledgeGapRepository.new, policy:, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
    )
    actor = Entities::Identity::Actor.new(user_id: session.student_id, role: :student)
    result = close.call(actor:, session: sessions.find_by_public_id(public_id: session.public_id), essential_id: session.exercise.essential_id)

    assert result.success?, result.errors.inspect
    session.reload.score_percent
  end

  def question_of(exercise, kind, position, points)
    question = exercise.questions.create!(position:, content: "Q#{position} ___", question_type: kind, points:)
    case kind
    when "single_choice", "true_false" then 3.times { |rank| question.answers.create!(position: rank + 1, content: "P#{rank}", correct: rank.zero?) }
    when "matching" then 3.times { |rank| question.answers.create!(position: rank + 1, content: "g#{rank}", match_content: "d#{rank}", correct: true) }
    else 3.times { |rank| question.answers.create!(position: rank + 1, content: (kind == "ordering" ? "e#{rank}" : "4"), correct: true) }
    end
    question
  end

  test "des copies à une case, de types et de barèmes variés : la note enregistrée à la clôture est celle d'avant" do
    random = Random.new(2026)
    40.times do |index|
      exercise = create_exercise(title: "Régression #{index}", questions: 0)
      rows = Array.new(random.rand(1..8)) do |position|
        points = BigDecimal(POINTS.sample(random:))
        [ question_of(exercise, KINDS.sample(random:), position + 1, points), points, random.rand < 0.6 ]
      end
      session = create_exercise_session(student: create_student, exercise:)
      rows.each_with_index do |(question, _points, correct), i|
        next if i == 3 # une question sans tentative est fausse

        Orm::QuestionAttempt.create!(exercise_session: session, question:, correct:, selected_answer_ids: [], response_text: (correct ? "4" : "5"), answered_at: Time.current)
      end
      expected = legacy_percent(rows.each_with_index.map { |(_, points, correct), i| [ points, i != 3 && correct ] })

      assert_equal expected, close!(session), "exercice #{index} : #{rows.map { |q, p, c| [ q.question_type, p.to_f, c ] }}"
    end
  end

  test "les copies terminées en base : le score enregistré est celui de la clôture, relu sur la session" do
    exercise = create_exercise(title: "Mixte", questions: 3)
    session = create_exercise_session(student: create_student, exercise:)
    exercise.questions.order(:position).each_with_index do |question, i|
      create_attempt(session:, question:, correct: i != 1)
    end

    assert_equal 66, close!(session)
    assert_equal "completed", session.status
    assert_equal 66, session.score_percent
    assert_equal 66, legacy_percent(exercise.questions.map.with_index { |question, i| [ question.points, i != 1 ] })
  end
end

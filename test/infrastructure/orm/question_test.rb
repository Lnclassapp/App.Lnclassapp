require "test_helper"

# ADR-0115 §6 : la migration pose les bornes en base, en plus de celles du domaine (menace.md, I1, I2, I8, W2, W8).
class Orm::QuestionTest < ActiveSupport::TestCase
  setup { @exercise = create_exercise(questions: 0) }

  def create_question(**attributes)
    Orm::Question.create!(exercise: @exercise, position: @exercise.questions.count + 1, content: "?", question_type: "single_choice",
                          **attributes)
  end

  test "une question existante vaut 1 point, sans unité, sans début de phrase, sans grille" do
    question = create_question.reload

    assert_equal [ BigDecimal("1"), nil, nil, [] ], [ question.points, question.unit, question.starter, question.criteria ]
  end

  test "points, unité, début de phrase et grille sont écrits et relus à l'identique" do
    question = create_question(question_type: "written", points: "2.5", unit: "km/h", starter: "Non, car…",
                               criteria: [ "Je cite la propriété", "Je conclus" ]).reload

    assert_equal [ BigDecimal("2.5"), "km/h", "Non, car…", [ "Je cite la propriété", "Je conclus" ] ],
                 [ question.points, question.unit, question.starter, question.criteria ]
  end

  test "la base refuse des points hors de 0,5 à 20 ou hors d'un demi-point" do
    %w[0 0.3 1.3 20.5 25].each_with_index do |points, index|
      assert_raises(ActiveRecord::CheckViolation, points) { create_question(points:, position: 10 + index) }
    end
    %w[0.5 1 1.5 19.5 20].each_with_index { |points, index| assert create_question(points:, position: 30 + index).persisted?, points }
  end

  test "la base borne l'unité à 10 caractères et le début de phrase à 150" do
    assert_raises(ActiveRecord::ValueTooLong) { create_question(unit: "a" * 11) }
    assert_raises(ActiveRecord::ValueTooLong) { create_question(starter: "a" * 151) }
    assert create_question(unit: "a" * 10, starter: "a" * 150).persisted?
  end

  test "la base accepte les trois types nouveaux et refuse un type inconnu" do
    %w[select written notebook].each_with_index { |type, index| assert create_question(question_type: type, position: 40 + index).persisted?, type }
    assert_raises(ActiveRecord::CheckViolation) { create_question(question_type: "open", position: 50) }
  end

  test "le sujet en blocs est une colonne jsonb facultative de l'exercice" do
    assert_nil @exercise.reload.statement_blocks

    @exercise.update!(statement_blocks: [ { "type" => "paragraph", "text" => "Un sujet." } ])

    assert_equal [ { "type" => "paragraph", "text" => "Un sujet." } ], @exercise.reload.statement_blocks
  end
end

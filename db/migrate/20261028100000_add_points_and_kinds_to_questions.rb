# ADR-0115 §6 (correction-comme-en-classe) : points, unité, début de phrase et grille sur les questions, trois types de
# questions de plus, réponse rédigée de 2 000 caractères, sujet de l'exercice en blocs.
class AddPointsAndKindsToQuestions < ActiveRecord::Migration[8.1]
  OLD_TYPES = %w[true_false single_choice multiple_correct_2 multiple_correct_3 fill_blank numeric ordering matching].freeze
  NEW_TYPES = (OLD_TYPES + %w[select written notebook]).freeze

  def up
    add_column :questions, :points, :decimal, precision: 4, scale: 1, null: false, default: 1
    add_column :questions, :unit, :string, limit: 10
    add_column :questions, :starter, :string, limit: 150
    add_column :questions, :criteria, :string, array: true, null: false, default: []
    add_check_constraint :questions, "points >= 0.5 AND points <= 20 AND points * 2 = round(points * 2)", name: "questions_points_range"
    replace_type_constraint(NEW_TYPES)
    change_column :question_attempts, :response_text, :string, limit: 2000
    add_column :exercises, :statement_blocks, :jsonb
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "des questions de type nouveau existent" if
      select_value("SELECT 1 FROM questions WHERE question_type IN ('select', 'written', 'notebook') LIMIT 1")
    raise ActiveRecord::IrreversibleMigration, "des réponses rédigées de plus de 200 caractères existent" if
      select_value("SELECT 1 FROM question_attempts WHERE char_length(response_text) > 200 LIMIT 1")

    remove_column :exercises, :statement_blocks
    change_column :question_attempts, :response_text, :string, limit: 200
    replace_type_constraint(OLD_TYPES)
    remove_check_constraint :questions, name: "questions_points_range"
    remove_column :questions, :criteria
    remove_column :questions, :starter
    remove_column :questions, :unit
    remove_column :questions, :points
  end

  private

  def replace_type_constraint(types)
    remove_check_constraint :questions, name: "questions_question_type_values"
    add_check_constraint :questions, "question_type IN (#{types.map { connection.quote(it) }.join(', ')})",
                         name: "questions_question_type_values"
  end
end

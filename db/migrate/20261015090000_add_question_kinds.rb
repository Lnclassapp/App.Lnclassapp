# ADR-0091 §4.1, Lot 0 of exercice-eleve: four new question types (fill_blank, numeric, ordering, matching) live on the
# existing tables. questions gains its numeric tolerance, answers the right-hand side of a matching pair, and an attempt
# may hold typed text instead of chosen answers. Rerunnable both ways; down refuses while a row of a new type exists,
# since the narrower CHECKs would no longer hold.
class AddQuestionKinds < ActiveRecord::Migration[8.1]
  TYPES = "questions_question_type_values".freeze
  OLD_TYPES = "question_type IN ('true_false','single_choice','multiple_correct_2','multiple_correct_3')".freeze
  NEW_TYPES = "question_type IN ('true_false','single_choice','multiple_correct_2','multiple_correct_3'," \
              "'fill_blank','numeric','ordering','matching')".freeze
  TOLERANCE = "questions_numeric_tolerance_positive".freeze
  SELECTION = "question_attempts_selected_answer_ids_present".freeze
  OLD_SELECTION = "cardinality(selected_answer_ids) > 0".freeze
  NEW_SELECTION = "cardinality(selected_answer_ids) > 0 OR response_text IS NOT NULL".freeze

  def up
    remove_check_constraint :questions, name: TYPES, if_exists: true
    add_check_constraint :questions, NEW_TYPES, name: TYPES
    add_column :questions, :numeric_tolerance, :decimal, precision: 12, scale: 4, if_not_exists: true
    add_check_constraint :questions, "numeric_tolerance >= 0", name: TOLERANCE, if_not_exists: true
    add_column :answers, :match_content, :string, limit: 500, if_not_exists: true
    add_column :question_attempts, :response_text, :string, limit: 200, if_not_exists: true
    remove_check_constraint :question_attempts, name: SELECTION, if_exists: true
    add_check_constraint :question_attempts, NEW_SELECTION, name: SELECTION
  end

  def down
    remove_check_constraint :question_attempts, name: SELECTION, if_exists: true
    add_check_constraint :question_attempts, OLD_SELECTION, name: SELECTION
    remove_column :question_attempts, :response_text, if_exists: true
    remove_column :answers, :match_content, if_exists: true
    remove_check_constraint :questions, name: TOLERANCE, if_exists: true
    remove_column :questions, :numeric_tolerance, if_exists: true
    remove_check_constraint :questions, name: TYPES, if_exists: true
    add_check_constraint :questions, OLD_TYPES, name: TYPES
  end
end

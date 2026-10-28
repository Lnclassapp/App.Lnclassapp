# ADR-0112 (copie-a-rendre) §4.2 : une copie rendue enregistre aussi les questions laissées vides.
class AddUnansweredToQuestionAttempts < ActiveRecord::Migration[8.1]
  def up
    add_column :question_attempts, :unanswered, :boolean, null: false, default: false
    remove_check_constraint :question_attempts, name: "question_attempts_selected_answer_ids_present"
    add_check_constraint :question_attempts, "unanswered OR cardinality(selected_answer_ids) > 0 OR response_text IS NOT NULL",
                         name: "question_attempts_selected_answer_ids_present"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "des copies d'élèves contiennent des questions laissées vides" if
      select_value("SELECT 1 FROM question_attempts WHERE unanswered LIMIT 1")

    remove_check_constraint :question_attempts, name: "question_attempts_selected_answer_ids_present"
    add_check_constraint :question_attempts, "cardinality(selected_answer_ids) > 0 OR response_text IS NOT NULL",
                         name: "question_attempts_selected_answer_ids_present"
    remove_column :question_attempts, :unanswered
  end
end

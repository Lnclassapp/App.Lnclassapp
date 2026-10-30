# ADR-XXXX questions à plusieurs cases et indice (je-m-entraine-dans-la-fiche) §4 et §6 : la case d'une réponse, les réponses par
# case d'une tentative, l'indice d'une question et les indices ouverts d'une copie. Tout est facultatif ou vaut 0 / vide :
# aucun exercice existant ne change de note ni de forme.
class AddBlanksAndHints < ActiveRecord::Migration[8.1]
  def change
    add_column :answers, :blank, :integer, limit: 2, null: false, default: 0
    add_check_constraint :answers, "blank BETWEEN 0 AND 5", name: "answers_blank_range"
    add_column :question_attempts, :blank_responses, :string, array: true, null: false, default: []
    add_column :question_attempts, :blank_results, :boolean, array: true, null: false, default: []
    add_column :questions, :hint, :string, limit: 500
    add_column :exercise_sessions, :hinted_question_ids, :bigint, array: true, null: false, default: []
  end
end

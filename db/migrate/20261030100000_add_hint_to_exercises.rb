# ADR-XXXX sujets-de-devoir §6 (prepare-interros-cahier, Lot 0) : l'indice d'un exercice, une phrase facultative montrée avant la vérification.
class AddHintToExercises < ActiveRecord::Migration[8.1]
  def change
    add_column :exercises, :hint, :text
    add_check_constraint :exercises, "hint IS NULL OR char_length(btrim(hint)) BETWEEN 1 AND 400", name: "exercises_hint_length"
  end
end

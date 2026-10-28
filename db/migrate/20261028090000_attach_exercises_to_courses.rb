# ADR-XXXX (refonte-page-lecon) : l'exercice appartient à sa leçon ; la notion devient facultative et la description un sujet.
# migration-en-deux-temps: le renommage description → statement se fait en un temps ; l'ancien code et le nouveau n'ont pas de période commune (pas d'utilisateurs réels, Q5).
class AttachExercisesToCourses < ActiveRecord::Migration[8.1]
  def up
    add_reference :exercises, :course, foreign_key: { on_delete: :restrict }, null: true
    execute <<~SQL
      UPDATE exercises SET course_id = essentials.course_id
      FROM essentials WHERE essentials.id = exercises.essential_id
    SQL
    remove_index :exercises, name: "index_exercises_on_essential_id_and_position"
    # La position était unique par notion : elle devient unique par leçon, dans l'ordre des notions puis des exercices.
    execute <<~SQL
      UPDATE exercises SET position = ranked.rank
      FROM (
        SELECT exercises.id, ROW_NUMBER() OVER (PARTITION BY exercises.course_id ORDER BY essentials.position, essentials.id, exercises.position) AS rank
        FROM exercises JOIN essentials ON essentials.id = exercises.essential_id
      ) ranked
      WHERE ranked.id = exercises.id
    SQL
    change_column_null :exercises, :course_id, false
    change_column_null :exercises, :essential_id, true
    rename_column :exercises, :description, :statement
    add_index :exercises, [ :course_id, :position ], unique: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "des exercices de toute la leçon n'ont pas de notion" if
      select_value("SELECT 1 FROM exercises WHERE essential_id IS NULL LIMIT 1")

    remove_index :exercises, column: [ :course_id, :position ]
    rename_column :exercises, :statement, :description
    change_column_null :exercises, :essential_id, false
    # Positions par notion, comme avant.
    execute <<~SQL
      UPDATE exercises SET position = ranked.rank
      FROM (SELECT id, ROW_NUMBER() OVER (PARTITION BY essential_id ORDER BY position) AS rank FROM exercises) ranked
      WHERE ranked.id = exercises.id
    SQL
    add_index :exercises, [ :essential_id, :position ], unique: true
    remove_reference :exercises, :course, foreign_key: true
  end
end

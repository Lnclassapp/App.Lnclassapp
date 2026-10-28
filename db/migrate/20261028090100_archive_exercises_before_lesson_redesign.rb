# ADR-XXXX (refonte-page-lecon) §4.5 : les exercices existants et leurs assignations sont archivés, pas supprimés (leurs
# sessions restent lisibles). Migration de données, irréversible : le contenu revient par l'import v2.
class ArchiveExercisesBeforeLessonRedesign < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE classroom_assignments SET status = 'archived', archived_at = NOW() WHERE status <> 'archived'"
    execute "UPDATE exercises SET status = 'archived', archived_at = NOW() WHERE status <> 'archived'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

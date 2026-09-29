# Chantier cache-ecrans-lourds, lot 2 (ADR-0062 §5, seuil de reprise ; ADR-0067): the team dashboard counts the rows of a
# period on four dates. Each gets its index, in the order of ADR-0062, so that a period reads its own rows instead of
# the whole table: the sessions started (with the student, for the distinct count), the sessions completed (partial,
# with the student and the score), the assignments, the accounts (with the id, for the latest signups). Built
# concurrently: no step blocks writes.
class AddPeriodIndexesForTeamDashboard < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :exercise_sessions, %i[started_at student_id], algorithm: :concurrently, if_not_exists: true
    add_index :exercise_sessions, :completed_at, name: "index_exercise_sessions_completed_on_completed_at",
                                                 include: %i[student_id score_percent], where: "status = 'completed'",
                                                 algorithm: :concurrently, if_not_exists: true
    add_index :users, %i[created_at id], algorithm: :concurrently, if_not_exists: true
    add_index :classroom_assignments, :assigned_at, algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :classroom_assignments, :assigned_at, algorithm: :concurrently, if_exists: true
    remove_index :users, %i[created_at id], algorithm: :concurrently, if_exists: true
    remove_index :exercise_sessions, name: "index_exercise_sessions_completed_on_completed_at", algorithm: :concurrently,
                                     if_exists: true
    remove_index :exercise_sessions, %i[started_at student_id], algorithm: :concurrently, if_exists: true
  end
end

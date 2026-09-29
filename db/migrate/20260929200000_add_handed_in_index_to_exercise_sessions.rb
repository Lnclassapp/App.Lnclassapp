# Chantier cache-ecrans-lourds, lot 1 (ADR-0067): « Travail des élèves » (ADR-0065 §4) reads the handed-in sessions of
# the assignments of a school's classrooms. A partial index on the completed standard sessions, keyed by assignment then
# student and carrying the score, lets that read stay an index-only scan. Built concurrently: no step blocks writes.
class AddHandedInIndexToExerciseSessions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  NAME = "index_exercise_sessions_handed_in".freeze

  def up
    add_index :exercise_sessions, %i[classroom_assignment_id student_id], include: :score_percent, name: NAME,
                                  where: "status = 'completed' AND kind = 'standard'", algorithm: :concurrently,
                                  if_not_exists: true
  end

  def down
    remove_index :exercise_sessions, name: NAME, algorithm: :concurrently, if_exists: true
  end
end

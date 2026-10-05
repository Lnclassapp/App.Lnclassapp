# Chantier remediation-comptee-faite (ADR-0072 §4.4, complément du 2026-10-04 (ter); ADR-0067, levier 1): a session done
# in remediation is handed in too, so the partial index of the handed-in sessions drops its condition on kind. Same key,
# same INCLUDE, same name. Built concurrently under a temporary name, then swapped: no step blocks writes, and the
# direction pages are never left without their index.
class CountRemediationInHandedInIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  NAME = "index_exercise_sessions_handed_in".freeze
  BUILDING = "index_exercise_sessions_handed_in_building".freeze
  COLUMNS = %i[classroom_assignment_id student_id].freeze

  def up = swap("status = 'completed'")

  def down = swap("status = 'completed' AND kind = 'standard'")

  private

  def swap(where)
    add_index :exercise_sessions, COLUMNS, include: :score_percent, name: BUILDING, where:, algorithm: :concurrently,
                                           if_not_exists: true
    remove_index :exercise_sessions, name: NAME, algorithm: :concurrently, if_exists: true
    rename_index :exercise_sessions, BUILDING, NAME
  end
end

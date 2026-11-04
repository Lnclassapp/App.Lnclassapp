# ADR-0121 (ajout du 2026-10-30, prepare-interros-cahier, Lot 0b) : l'envoi qui a créé l'assignation ; nul pour un exercice assigné seul.
class AddBatchPublicIdToClassroomAssignments < ActiveRecord::Migration[8.1]
  def change
    add_column :classroom_assignments, :batch_public_id, :string, limit: 14
    add_index :classroom_assignments, %i[classroom_id batch_public_id], name: "index_classroom_assignments_on_classroom_and_batch"
  end
end

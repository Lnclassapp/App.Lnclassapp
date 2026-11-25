# parametrage-notifications, Lot 0 (ADR-XXXX §4.1) : la case « Prévenir les élèves » des annonces et le 7e motif.
class AddPushRequestedAndAssignmentNew < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :push_requested, :boolean, null: false, default: false

    reversible do |direction|
      direction.up do
        remove_check_constraint :push_deliveries, name: "push_deliveries_motive_check"
        add_check_constraint :push_deliveries,
                             "motive IN ('inactive','assignment_due','assignment_new','quiz_prep','announcement','result','unfinished')",
                             name: "push_deliveries_motive_check"
      end
      direction.down do
        remove_check_constraint :push_deliveries, name: "push_deliveries_motive_check"
        add_check_constraint :push_deliveries,
                             "motive IN ('inactive','assignment_due','quiz_prep','announcement','result','unfinished')",
                             name: "push_deliveries_motive_check"
      end
    end
  end
end

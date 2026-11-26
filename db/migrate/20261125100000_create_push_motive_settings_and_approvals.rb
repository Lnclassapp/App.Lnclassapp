# parametrage-notifications, Lot 0 (ADR-XXXX envois de notifications, §4.1) : réglages des motifs automatiques, historique, validations du jour.
# Tables neuves : l'image précédente les ignore.
class CreatePushMotiveSettingsAndApprovals < ActiveRecord::Migration[8.1]
  def change
    create_table :push_motive_settings do |t|
      t.string :motive, null: false
      t.boolean :automatic, null: false, default: false
      t.references :updated_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :updated_at, null: false
      t.index :motive, unique: true
    end
    add_check_constraint :push_motive_settings, "motive IN ('quiz_prep','assignment_due','assignment_new')",
                         name: "push_motive_settings_motive_check"

    create_table :push_motive_setting_changes do |t|
      t.string :motive, null: false
      t.boolean :automatic, null: false
      t.references :changed_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :changed_at, null: false
      t.index :changed_at
    end
    add_check_constraint :push_motive_setting_changes, "motive IN ('quiz_prep','assignment_due','assignment_new')",
                         name: "push_motive_setting_changes_motive_check"

    create_table :push_approvals do |t|
      t.date :on_date, null: false
      t.string :motive, null: false
      t.references :approved_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :approved_at, null: false
      t.integer :recipients_count, null: false, default: 0
      t.index %i[on_date motive], unique: true
    end
    add_check_constraint :push_approvals, "motive IN ('quiz_prep','assignment_due','assignment_new','unfinished','result','inactive')",
                         name: "push_approvals_motive_check"

    create_table :push_approval_recipients do |t|
      t.references :push_approval, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :object_key, null: false
      t.index %i[push_approval_id user_id object_key], unique: true, name: "index_push_approval_recipients_unique"
    end
  end
end

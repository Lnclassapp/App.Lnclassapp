# ADR-0077 §4.1: how a direction account joined its school (team invitation or the school's code), and its archiving.
# An archived account cannot sign in and frees its place; the daily purge deletes it 30 days later.
class AddJoiningAndArchivingToSchoolStaffs < ActiveRecord::Migration[8.1]
  def change
    change_table :school_staffs, bulk: true do |t|
      t.string :joined_via, null: false, default: "invitation"
      t.datetime :archived_at
      t.references :archived_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.check_constraint "joined_via IN ('invitation', 'code')", name: "school_staffs_joined_via_values"
      t.check_constraint "(archived_at IS NULL) = (archived_by_id IS NULL)", name: "school_staffs_archived_together"
      # The cap of ADR-0077 counts the active accounts that joined by code, per school.
      t.index %i[school_id joined_via], where: "archived_at IS NULL", name: "index_school_staffs_on_school_id_and_joined_via"
      t.index :archived_at, where: "archived_at IS NOT NULL"
    end
  end
end

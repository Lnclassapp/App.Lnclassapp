# ADR-0063: a teacher who signed up without school code waits here, without any teacher_schools row, until the team or
# an active colleague of the same school (the sponsor) decides. One request per teacher.
class CreateSchoolJoinRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :school_join_requests do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.references :teacher, null: false, foreign_key: { to_table: :users, on_delete: :restrict }, index: { unique: true }
      t.references :school, null: false, foreign_key: { on_delete: :restrict }, index: false
      t.string :status, null: false, default: "pending"
      t.datetime :decided_at
      t.references :decided_by, foreign_key: { to_table: :users, on_delete: :restrict }, index: true
      t.string :decided_via
      t.timestamps
      t.index %i[school_id status]
      t.check_constraint "status IN ('pending', 'approved', 'rejected')", name: "school_join_requests_status_values"
      t.check_constraint "decided_via IN ('team', 'sponsor')", name: "school_join_requests_decided_via_values"
      t.check_constraint "(status = 'pending') = (decided_at IS NULL)", name: "school_join_requests_decided_iff_not_pending"
    end
  end
end

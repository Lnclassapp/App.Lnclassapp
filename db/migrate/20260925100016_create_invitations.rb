# ADR-0038, ADR-0044 : team and school staff invitations.
class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.string :kind, null: false
      t.string :contact, limit: 10, null: false
      t.string :team_role
      t.references :school, foreign_key: { on_delete: :restrict }
      t.string :position
      t.references :invited_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :token_digest, limit: 64, null: false, index: { unique: true }
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.references :accepted_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :revoked_at
      t.timestamps
      t.index [ :kind, :contact ], unique: true, where: "accepted_at IS NULL AND revoked_at IS NULL",
                                   name: "index_invitations_one_pending"
    end

    add_check_constraint :invitations, "kind IN ('team','school_staff')", name: "invitations_kind_values"
    add_check_constraint :invitations, "contact ~ '^0[157][0-9]{8}$'", name: "invitations_contact_format"
    add_check_constraint :invitations, "team_role IN ('admin','content','field')", name: "invitations_team_role_values"
    add_check_constraint :invitations, "position IN ('principal','censor','educator','secretary')",
                         name: "invitations_position_values"
    add_check_constraint :invitations, "kind <> 'team' OR team_role IS NOT NULL", name: "invitations_team_has_role"
    add_check_constraint :invitations, "kind <> 'school_staff' OR (school_id IS NOT NULL AND position IS NOT NULL)",
                         name: "invitations_staff_has_school"
  end
end

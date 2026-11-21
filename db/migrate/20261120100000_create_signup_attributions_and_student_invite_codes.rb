# partage-classe-k-factor, Lot 0 (ADR attribution-des-inscriptions-eleves §4.1) : la source de chaque inscription élève (écrite une fois)
# et le code d'invitation opaque de chaque élève. Tables neuves : l'image précédente les ignore.
class CreateSignupAttributionsAndStudentInviteCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :signup_attributions do |t|
      t.references :student, null: false, foreign_key: { to_table: :users, on_delete: :cascade }, index: { unique: true }
      t.references :classroom, null: false, foreign_key: { on_delete: :restrict }
      t.string :source, null: false
      t.references :inviter, null: true, foreign_key: { to_table: :users, on_delete: :nullify }, index: { where: "inviter_id IS NOT NULL" }
      t.datetime :created_at, null: false, default: -> { "now()" }
      t.index :created_at
      t.check_constraint "source IN ('qr','student_invite','teacher_link','code','cold')", name: "signup_attributions_source_known"
      t.check_constraint "inviter_id IS NULL OR source = 'student_invite'", name: "signup_attributions_inviter_only_for_invite"
      t.check_constraint "inviter_id IS NULL OR inviter_id <> student_id", name: "signup_attributions_inviter_not_self"
    end

    create_table :student_invite_codes do |t|
      t.references :student, null: false, foreign_key: { to_table: :users, on_delete: :cascade }, index: { unique: true }
      t.string :code, limit: 8, null: false
      t.datetime :created_at, null: false, default: -> { "now()" }
      t.index :code, unique: true
      t.check_constraint "code ~ '^[a-hjkmnp-z2-9]{8}$'", name: "student_invite_codes_code_format"
    end
  end
end

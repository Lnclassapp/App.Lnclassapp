# ADR-0027, ADR-0030 : attributes of the teacher role.
class CreateTeacherProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :teacher_profiles do |t|
      t.references :user, null: false, foreign_key: { on_delete: :restrict }, index: { unique: true }
      t.references :material, null: false, foreign_key: { on_delete: :restrict }
      t.datetime :onboarding_completed_at
      t.timestamps
    end
  end
end

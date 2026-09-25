# ADR-0029, ADR-0034 : regional directorates, created on screen by the team.
# The frozen slug is the target of the school imports (ADR-0039).
class CreateDrenas < ActiveRecord::Migration[8.1]
  def change
    create_table :drenas do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.string :name, limit: 80, null: false, index: { unique: true }
      t.string :slug, null: false, index: { unique: true }
      t.timestamps
    end
  end
end

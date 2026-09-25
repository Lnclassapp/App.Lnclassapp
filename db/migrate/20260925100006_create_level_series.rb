# ADR-0034 : series offered at a level; a series is accepted on a classroom or a course only through this pair.
class CreateLevelSeries < ActiveRecord::Migration[8.1]
  def change
    create_table :level_series do |t|
      t.references :level, null: false, foreign_key: { on_delete: :restrict }, index: false
      t.references :series, null: false, foreign_key: { on_delete: :restrict }
      t.datetime :created_at, null: false
      t.index [ :level_id, :series_id ], unique: true
    end
  end
end

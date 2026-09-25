# ADR-0034 : series of the second cycle; the frozen slug is the code of the classroom plan (ADR-0030).
class CreateSeries < ActiveRecord::Migration[8.1]
  def change
    create_table :series do |t|
      t.string :name, limit: 10, null: false, index: { unique: true }
      t.string :slug, null: false, index: { unique: true }
      t.timestamps
    end
  end
end

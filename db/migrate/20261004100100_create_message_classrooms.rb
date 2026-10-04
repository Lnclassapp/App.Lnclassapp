# ADR-0078 §4.1: the classrooms a teacher's announcement targets; they go with the message, a classroom stays.
class CreateMessageClassrooms < ActiveRecord::Migration[8.1]
  def change
    create_table :message_classrooms do |t|
      t.references :message, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :classroom, null: false, foreign_key: { on_delete: :restrict }, index: true
      t.index %i[message_id classroom_id], unique: true
    end
  end
end

# ADR-0045 §4 (unchanged by ADR-0078): « Ne plus afficher » holds on every device; one dismissal per message and account.
class CreateMessageDismissals < ActiveRecord::Migration[8.1]
  def change
    create_table :message_dismissals do |t|
      t.references :message, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: { on_delete: :restrict }, index: true
      t.datetime :dismissed_at, null: false
      t.index %i[message_id user_id], unique: true
    end
  end
end

# notifications-push, Lot 0 (ADR-XXXX-notifications-web-push-aux-eleves §4.1) : abonnements Web Push, préférence, envois.
# Tables neuves : l'image précédente les ignore. Rien n'est gardé au-delà de ce qu'il faut pour envoyer.
class CreatePushTables < ActiveRecord::Migration[8.1]
  def change
    create_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :restrict }
      # Une session expirée ou supprimée ne supprime pas l'abonnement : l'élève décroché reste joignable.
      t.references :session, null: true, foreign_key: { on_delete: :nullify }
      t.text :endpoint, null: false
      t.string :p256dh, null: false
      t.string :auth, null: false
      t.datetime :last_success_at
      t.integer :failure_count, null: false, default: 0
      t.timestamps
      t.index :endpoint, unique: true
    end

    create_table :push_preferences do |t|
      t.references :user, null: false, foreign_key: { on_delete: :restrict }, index: { unique: true }
      t.datetime :turned_off_at
      t.datetime :invitation_postponed_until
      t.timestamps
    end

    create_table :push_deliveries do |t|
      t.references :user, null: false, foreign_key: { on_delete: :restrict }, index: false
      t.string :motive, null: false
      t.string :object_key, null: false
      t.datetime :sent_at, null: false
      t.string :status, null: false
      t.index %i[user_id motive object_key], unique: true, name: "index_push_deliveries_on_user_motive_object"
      t.index %i[user_id sent_at]
      t.index :sent_at
    end

    add_check_constraint :push_deliveries,
                         "motive IN ('inactive','assignment_due','quiz_prep','announcement','result','unfinished')",
                         name: "push_deliveries_motive_check"
    add_check_constraint :push_deliveries,
                         "status IN ('delivered','gone','retry','failed','disabled','not_configured')",
                         name: "push_deliveries_status_check"
  end
end

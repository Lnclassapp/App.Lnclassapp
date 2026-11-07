# ADR cartes-activation (contexte billing, §4.1) : points relais, leurs écoles, lots, cartes d'activation et versements.
# Le code d'une carte est chiffré de façon déterministe (index unique sur le chiffré) ; le numéro lisible vient d'une séquence.
# created_by_id et recorded_by_id restent nullables : les fixtures de test n'ont pas de compte d'équipe, les use cases les renseignent toujours.
class CreateBillingTables < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_relay_points do |t|
      t.string :public_id, limit: 14, null: false
      t.string :name, limit: 80, null: false
      t.string :location, limit: 120, null: false
      t.string :phone, limit: 20, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :billing_relay_points, :public_id, unique: true

    create_table :billing_relay_point_schools do |t|
      t.references :relay_point, null: false, foreign_key: { to_table: :billing_relay_points, on_delete: :restrict }, index: false
      t.references :school, null: false, foreign_key: { on_delete: :restrict }
    end
    add_index :billing_relay_point_schools, %i[relay_point_id school_id], unique: true, name: "index_billing_relay_point_schools_on_pair"

    create_table :billing_card_batches do |t|
      t.string :public_id, limit: 14, null: false
      t.references :relay_point, null: false, foreign_key: { to_table: :billing_relay_points, on_delete: :restrict }
      t.integer :quantity, null: false
      t.integer :unit_price_xof, null: false
      t.date :valid_until, null: false
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :created_at, null: false
    end
    add_index :billing_card_batches, :public_id, unique: true
    add_check_constraint :billing_card_batches, "quantity BETWEEN 1 AND 200", name: "billing_card_batches_quantity_range"
    add_check_constraint :billing_card_batches, "unit_price_xof >= 0", name: "billing_card_batches_price_positive"

    create_table :billing_activation_cards do |t|
      t.string :public_id, limit: 14, null: false
      t.references :batch, null: false, foreign_key: { to_table: :billing_card_batches, on_delete: :restrict }
      t.references :relay_point, null: false, foreign_key: { to_table: :billing_relay_points, on_delete: :restrict }
      t.bigserial :serial, null: false
      t.string :code, null: false
      t.integer :price_xof, null: false
      t.date :valid_until, null: false
      t.string :state, null: false, default: "issued"
      t.references :student, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :school, foreign_key: { on_delete: :restrict }
      t.datetime :activated_at
      t.datetime :cancelled_at
      t.references :cancelled_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :cancel_reason, limit: 200
    end
    add_index :billing_activation_cards, :public_id, unique: true
    add_index :billing_activation_cards, :serial, unique: true
    add_index :billing_activation_cards, :code, unique: true
    add_index :billing_activation_cards, %i[relay_point_id state]
    add_index :billing_activation_cards, %i[student_id valid_until], unique: true, where: "state = 'activated'",
                                                                      name: "index_billing_activation_cards_one_subscription_per_year"
    add_check_constraint :billing_activation_cards, "state IN ('issued', 'activated', 'cancelled')", name: "billing_activation_cards_state_values"
    add_check_constraint :billing_activation_cards, "price_xof >= 0", name: "billing_activation_cards_price_positive"

    create_table :billing_remittances do |t|
      t.string :public_id, limit: 14, null: false
      t.references :relay_point, null: false, foreign_key: { to_table: :billing_relay_points, on_delete: :restrict }
      t.integer :amount_xof, null: false
      t.datetime :received_at, null: false
      t.string :reference, limit: 60
      t.string :reason, limit: 200
      t.references :recorded_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :created_at, null: false
    end
    add_index :billing_remittances, :public_id, unique: true
    add_check_constraint :billing_remittances, "amount_xof <> 0", name: "billing_remittances_amount_not_zero"
    add_check_constraint :billing_remittances, "amount_xof > 0 OR char_length(btrim(coalesce(reason, ''))) > 0",
                         name: "billing_remittances_correction_has_reason"
  end
end

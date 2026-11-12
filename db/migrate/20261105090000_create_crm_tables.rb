# ADR-XXXX (contexte crm) et ADR-XXXX (modèles de langage), Lot 0 : les cinq tables du suivi des écoles. Clés vers `schools`
# en cascade (une école supprimée emporte son suivi) ; vers `users` sans cascade (un compte s'anonymise, il ne disparaît pas).
class CreateCrmTables < ActiveRecord::Migration[8.1]
  def change
    create_table :crm_accounts do |t|
      t.references :school, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :stage, null: false, default: "prospect"
      t.references :owner, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :lost_reason
      t.datetime :stage_changed_at, null: false
      t.timestamps
      t.check_constraint "stage IN ('prospect', 'demo_done', 'subscribed', 'lost')", name: "crm_accounts_stage_values"
      t.check_constraint "lost_reason IS NULL OR lost_reason IN ('price', 'equipment', 'network', 'calendar', 'competitor', 'no_interest', 'other')",
                         name: "crm_accounts_lost_reason_values"
      t.check_constraint "stage <> 'lost' OR lost_reason IS NOT NULL", name: "crm_accounts_lost_has_reason"
    end

    create_table :crm_contacts do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.references :school, null: false, foreign_key: { on_delete: :cascade }
      t.string :full_name, limit: 80, null: false
      t.string :position, null: false
      t.string :phone, limit: 10
      t.string :note, limit: 500
      t.references :created_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :archived_at
      t.timestamps
      t.index %i[school_id archived_at], name: "index_crm_contacts_on_school_and_archived"
      t.check_constraint "position IN ('director', 'censor', 'educator', 'teacher', 'founder', 'other')", name: "crm_contacts_position_values"
      t.check_constraint "phone IS NULL OR phone ~ '^0[157][0-9]{8}$'", name: "crm_contacts_phone_format"
      t.check_constraint "btrim(full_name) <> ''", name: "crm_contacts_name_present"
    end

    create_table :crm_interactions do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.references :school, null: false, foreign_key: { on_delete: :cascade }
      t.references :author, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :kind, null: false
      t.datetime :occurred_at, null: false
      t.references :contact, foreign_key: { to_table: :crm_contacts, on_delete: :restrict }
      t.string :contact_name, limit: 80
      t.string :outcome, null: false
      t.string :next_step, limit: 200
      t.string :note, limit: 2000
      t.string :source, null: false, default: "manual"
      t.timestamps
      t.index %i[school_id occurred_at], name: "index_crm_interactions_on_school_and_occurred_at"
      t.check_constraint "kind IN ('call', 'whatsapp', 'visit', 'demo', 'other')", name: "crm_interactions_kind_values"
      t.check_constraint "outcome IN ('positive', 'neutral', 'negative')", name: "crm_interactions_outcome_values"
      t.check_constraint "source IN ('manual', 'dictation')", name: "crm_interactions_source_values"
    end

    create_table :crm_follow_ups do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.references :school, null: false, foreign_key: { on_delete: :cascade }
      t.references :assignee, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.date :due_on, null: false
      t.string :reason, limit: 200, null: false
      t.string :status, null: false, default: "open"
      t.datetime :done_at
      t.references :done_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :created_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :interaction, foreign_key: { to_table: :crm_interactions, on_delete: :restrict }
      t.timestamps
      t.index %i[assignee_id status due_on], name: "index_crm_follow_ups_on_assignee_status_due"
      t.check_constraint "status IN ('open', 'done')", name: "crm_follow_ups_status_values"
      t.check_constraint "(status = 'done') = (done_at IS NOT NULL AND done_by_id IS NOT NULL) AND (done_at IS NULL) = (done_by_id IS NULL)",
                         name: "crm_follow_ups_done_together"
    end

    create_table :crm_generations do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.references :school, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.string :status, null: false, default: "pending"
      t.references :requested_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :follow_up, foreign_key: { to_table: :crm_follow_ups, on_delete: :restrict }
      t.string :input_fingerprint, limit: 64
      t.text :content
      t.string :error_code
      t.string :model
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :duration_ms
      t.timestamps
      t.index %i[school_id kind], unique: true, where: "status = 'pending'", name: "index_crm_generations_one_pending"
      t.index %i[school_id kind created_at], name: "index_crm_generations_on_school_kind_created"
      t.check_constraint "kind IN ('briefing', 'dictation', 'whatsapp_draft', 'pedagogy_report')", name: "crm_generations_kind_values"
      t.check_constraint "status IN ('pending', 'done', 'failed')", name: "crm_generations_status_values"
    end
  end
end

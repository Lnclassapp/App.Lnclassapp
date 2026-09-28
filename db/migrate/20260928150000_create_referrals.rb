# ADR-0063: the referral loop. Every teacher profile draws an opaque token (48 random bits of a UUID v4) by the database
# default, so that sign-up, seeds, factories and existing rows all get one without touching a write path. A referee has
# one referrer; a share is a click on « Partager », recorded server side, without IP nor user agent (ADR-0049).
class CreateReferrals < ActiveRecord::Migration[8.1]
  TOKEN_DEFAULT = "substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)".freeze

  def change
    # A volatile default rewrites teacher_profiles once, filling every existing row: a small table, a short lock.
    add_column :teacher_profiles, :referral_token, :string, limit: 12, null: false, default: -> { TOKEN_DEFAULT }
    add_index :teacher_profiles, :referral_token, unique: true
    add_check_constraint :teacher_profiles, "referral_token ~ '^[0-9a-f]{12}$'", name: "teacher_profiles_referral_token_format"

    create_table :referrals do |t|
      t.references :referrer, null: false, foreign_key: { to_table: :users, on_delete: :restrict }, index: true
      t.references :referee, null: false, foreign_key: { to_table: :users, on_delete: :restrict }, index: { unique: true }
      t.references :school, null: false, foreign_key: { on_delete: :restrict }, index: true
      t.string :source, null: false
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.index :created_at
      t.check_constraint "source IN ('link', 'sponsor')", name: "referrals_source_values"
      t.check_constraint "referrer_id <> referee_id", name: "referrals_not_self"
    end

    create_table :referral_shares do |t|
      t.references :user, null: false, foreign_key: { on_delete: :restrict }, index: false
      t.string :channel, null: false
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.index %i[user_id created_at]
      t.index :created_at
      t.check_constraint "channel IN ('whatsapp', 'sms', 'copy', 'native')", name: "referral_shares_channel_values"
    end
  end
end

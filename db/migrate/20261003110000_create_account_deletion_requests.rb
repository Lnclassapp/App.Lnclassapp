# ADR-0036, amendment (2) of 2026-10-02: a deletion request is recorded when the support receives it, and stays visible
# until the team processes it (the account is anonymized) or cancels it. One pending request per account; nothing is
# ever deleted (RESTRICT), so the journal of who recorded and who closed a request stays readable.
class CreateAccountDeletionRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :account_deletion_requests do |t|
      t.references :user, null: false, foreign_key: { on_delete: :restrict }
      t.date :requested_on, null: false
      t.references :recorded_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :status, null: false, default: "pending"
      t.datetime :closed_at
      t.references :closed_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.timestamps
      t.check_constraint "status IN ('pending','processed','cancelled')", name: "account_deletion_requests_status_values"
      t.check_constraint "(status = 'pending') = (closed_at IS NULL)", name: "account_deletion_requests_closed_iff_not_pending"
      t.check_constraint "(closed_at IS NULL) = (closed_by_id IS NULL)", name: "account_deletion_requests_closed_together"
      t.index :user_id, unique: true, where: "status = 'pending'", name: "index_account_deletion_requests_one_pending"
      t.index %i[status requested_on]
    end
  end
end

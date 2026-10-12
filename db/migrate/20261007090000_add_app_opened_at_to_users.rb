# ADR-0082 §4.3: the last time an account opened Lnclass from the installed app's icon (start_url "/?source=app"), at
# the server's time. Read only aggregated by the team's pilotage (§4.4): no index. Cleared on anonymization (ADR-0036).
class AddAppOpenedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :app_opened_at, :datetime
  end
end

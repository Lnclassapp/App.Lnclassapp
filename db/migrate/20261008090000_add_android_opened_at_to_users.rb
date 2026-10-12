# ADR-0084 §4.6, amending ADR-0070 R3 and ADR-0082 §4.4: the last time an account opened the Android app « Lnclass »
# (start URL "/?source=android" from a recognised shell), at the server's time. Sister of app_opened_at (the installed
# web app); read only aggregated by the team's pilotage: no index. Cleared on anonymization (ADR-0036).
class AddAndroidOpenedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :android_opened_at, :datetime
  end
end

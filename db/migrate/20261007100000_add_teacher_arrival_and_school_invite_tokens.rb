# ADR-0083 §4.1, §4.2: a teacher signs up through the standard way or through an invite link /i/<token>. Every school
# draws two opaque invite tokens (direction, team) by the database default, in the shape of the referral token
# (ADR-0063), so that imports, seeds and existing rows all get them without touching a write path. Every teacher profile
# records its arrival channel: existing teachers receive the one deduced from what is known of them (a link referral
# gives colleague, then a join request gives standard, otherwise code, the historical way), then the column loses its
# default: every write names its channel. Rerunnable: the deduction runs only when this migration creates the column,
# so up again leaves the tokens and every channel alone, even a teacher still on « code » whose join request or link
# referral came later (test/db/growth_migrations_test.rb replays it).
class AddTeacherArrivalAndSchoolInviteTokens < ActiveRecord::Migration[8.1]
  TOKEN_DEFAULT = "substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)".freeze
  TOKENS = %i[direction_invite_token team_invite_token].freeze
  CHANNELS = "joined_via IN ('standard', 'colleague', 'direction', 'team', 'code')".freeze
  CHANNELS_CHECK = "teacher_profiles_joined_via_values".freeze

  def up
    TOKENS.each do |column|
      # A volatile default rewrites schools once (~3 900 rows), filling every existing row: a short lock.
      add_column :schools, column, :string, limit: 12, null: false, default: -> { TOKEN_DEFAULT }, if_not_exists: true
      add_index :schools, column, unique: true, if_not_exists: true
      add_check_constraint :schools, "#{column} ~ '^[0-9a-f]{12}$'", name: "schools_#{column}_format", if_not_exists: true
    end

    created = !column_exists?(:teacher_profiles, :joined_via)
    add_column :teacher_profiles, :joined_via, :string, null: false, default: "code" if created
    add_check_constraint :teacher_profiles, CHANNELS, name: CHANNELS_CHECK, if_not_exists: true
    return unless created

    backfill_joined_via
    change_column_default :teacher_profiles, :joined_via, from: "code", to: nil
  end

  # Loses the arrival channels and the invite tokens: an up after it deduces the channels again and draws new tokens,
  # so every /i/<token> link of a direction or the team shared before stops working.
  def down
    remove_column :teacher_profiles, :joined_via, if_exists: true
    TOKENS.each { remove_column :schools, it, if_exists: true }
  end

  private

  # Just after the column is created, every row is on « code »: the deduction then only reads the history.
  def backfill_joined_via
    execute <<~SQL.squish
      UPDATE teacher_profiles p SET joined_via = 'colleague'
      WHERE p.joined_via = 'code'
        AND EXISTS (SELECT 1 FROM referrals r WHERE r.referee_id = p.user_id AND r.source = 'link')
    SQL
    execute <<~SQL.squish
      UPDATE teacher_profiles p SET joined_via = 'standard'
      WHERE p.joined_via = 'code'
        AND EXISTS (SELECT 1 FROM school_join_requests j WHERE j.teacher_id = p.user_id)
    SQL
  end
end

# ADR-0085 §4.1, §4.4, §4.5: a student enters a classroom chosen in the cascade or given by a link /c/<token>, without
# a classroom code. Every classroom draws an opaque link token by the database default, in the shape of the invite
# tokens (ADR-0083), so that generation, imports, seeds and existing rows all get one without touching a write path.
# Every membership records its arrival channel: the existing ones receive « code », the historical way, then the
# column loses its default: every write names its channel. A removal is kept on the membership itself (removed_at,
# removed_by_id): it only exists on a membership that has ended, and always names who removed. Rerunnable: up again
# leaves the tokens and every channel already written alone.
class AddClassroomLinkTokensAndStudentRemoval < ActiveRecord::Migration[8.1]
  TOKEN_DEFAULT = "substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)".freeze
  CHANNELS = "joined_via IN ('standard', 'link', 'code')".freeze
  CHECKS = {
    "classroom_students_joined_via_values" => CHANNELS,
    "classroom_students_removed_only_when_left" => "removed_at IS NULL OR left_at IS NOT NULL",
    "classroom_students_removed_by_iff_removed" => "(removed_at IS NULL) = (removed_by_id IS NULL)"
  }.freeze

  def up
    # A volatile default rewrites classrooms once, filling every existing row: a short lock.
    add_column :classrooms, :link_token, :string, limit: 12, null: false, default: -> { TOKEN_DEFAULT }, if_not_exists: true
    add_index :classrooms, :link_token, unique: true, if_not_exists: true
    add_check_constraint :classrooms, "link_token ~ '^[0-9a-f]{12}$'", name: "classrooms_link_token_format", if_not_exists: true

    add_arrival_channel
    add_column :classroom_students, :removed_at, :datetime, if_not_exists: true
    add_reference :classroom_students, :removed_by, foreign_key: { to_table: :users, on_delete: :restrict },
                                                    index: { where: "removed_by_id IS NOT NULL" }, if_not_exists: true
    CHECKS.each { |name, expression| add_check_constraint :classroom_students, expression, name:, if_not_exists: true }
  end

  def down
    %i[removed_by_id removed_at joined_via].each { remove_column :classroom_students, it, if_exists: true }
    remove_column :classrooms, :link_token, if_exists: true
  end

  private

  # The default « code » only serves the rows that exist when the column arrives: a second run finds the column and
  # leaves it, and every channel in it, alone.
  def add_arrival_channel
    return if column_exists?(:classroom_students, :joined_via)

    add_column :classroom_students, :joined_via, :string, null: false, default: "code"
    change_column_default :classroom_students, :joined_via, from: "code", to: nil
  end
end

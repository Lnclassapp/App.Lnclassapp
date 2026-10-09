require "test_helper"
require Rails.root.join("db/migrate/20261008120000_remove_classroom_join_codes").to_s

# IL-02 (ADR-0085 §4.1, Lot F): on a live database, the classroom code leaves with its index and its format; the classrooms
# and their link tokens stay. Each test runs in the rolled back transaction of the test: PostgreSQL rolls the columns back
# with it.
class RemoveClassroomJoinCodesMigrationTest < ActiveSupport::TestCase
  def connection = ActiveRecord::Base.connection

  def migrate(direction)
    changing_schema do
      ActiveRecord::Migration.suppress_messages { RemoveClassroomJoinCodes.new.migrate(direction) }
    end
    Orm::Classroom.reset_column_information
  end

  teardown { Orm::Classroom.reset_column_information }

  def join_code_columns = connection.columns("classrooms").map(&:name) & %w[join_code join_code_rotated_at]

  test "IL-02: up removes the code, its rotation date, its index and its format; the classrooms keep their link" do
    classroom = create_classroom
    token = classroom.reload.link_token

    migrate(:down)
    assert_equal %w[join_code join_code_rotated_at], join_code_columns
    assert(connection.indexes("classrooms").any? { it.columns == %w[join_code] })
    assert_match(/join_code/, connection.check_constraints("classrooms").map(&:expression).join)

    migrate(:up)
    assert_empty join_code_columns
    assert_empty connection.indexes("classrooms").select { it.columns.include?("join_code") }
    assert_no_match(/join_code/, connection.check_constraints("classrooms").map(&:expression).join)
    assert_equal token, Orm::Classroom.find(classroom.id).link_token
  end

  test "the migration reruns both ways without failing" do
    migrate(:up)
    migrate(:down)
    migrate(:down)

    assert_equal %w[join_code join_code_rotated_at], join_code_columns

    migrate(:up)
    migrate(:up)

    assert_empty join_code_columns
  end
end

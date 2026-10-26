require "test_helper"
require Rails.root.join("db/migrate/20261024090000_add_join_code_to_classrooms").to_s

# CA-B1 (ADR-XXXX code-de-classe-a-six-caracteres §4, §6): on a live database, every classroom gets a code of 6 symbols,
# unique, lower case, and the database refuses anything else. Each test runs in the rolled back transaction of the test:
# PostgreSQL rolls the columns back with it.
class AddClassroomJoinCodesMigrationTest < ActiveSupport::TestCase
  def connection = ActiveRecord::Base.connection

  def migrate(direction)
    changing_schema do
      ActiveRecord::Migration.suppress_messages { AddJoinCodeToClassrooms.new.migrate(direction) }
    end
    Orm::Classroom.reset_column_information
  end

  teardown { Orm::Classroom.reset_column_information }

  def join_code_column = connection.columns("classrooms").find { it.name == "join_code" }

  test "up fills every existing classroom with a valid, distinct code, then forbids a missing or malformed one" do
    migrate(:down)
    ids = Array.new(5) { create_classroom.id }

    migrate(:up)

    codes = Orm::Classroom.where(id: ids).pluck(:join_code)
    assert_equal 5, codes.uniq.size
    assert(codes.all? { Entities::Classroom::JoinCode.valid?(it) }, codes.inspect)
    assert_equal [ "character varying", 6, false ], [ join_code_column.sql_type_metadata.sql_type.sub(/\(\d+\)/, ""),
                                                      join_code_column.limit, join_code_column.null ]
    assert(connection.indexes("classrooms").any? { it.columns == %w[join_code] && it.unique })
    assert_match(/join_code/, connection.check_constraints("classrooms").map(&:expression).join)
  end

  test "CA-B1: a new classroom has a code of the right format without anyone drawing it" do
    classroom = create_classroom

    assert Entities::Classroom::JoinCode.valid?(classroom.reload.join_code)
  end

  test "a classroom written without a code, by bulk insert or raw SQL, still gets a valid, distinct one from the database" do
    school = create_school
    level = create_level
    rows = Array.new(20) { |i| { public_id: "bulk#{i.to_s.rjust(10, '0')}", school_id: school.id, level_id: level.id, name: "B#{i}",
                                 school_year: current_school_year, created_at: Time.current, updated_at: Time.current } }
    Orm::Classroom.insert_all!(rows)

    codes = Orm::Classroom.where(school_id: school.id).pluck(:join_code)
    assert_equal 20, codes.uniq.size
    assert(codes.all? { Entities::Classroom::JoinCode.valid?(it) }, codes.inspect)
    assert_equal 31, Entities::Classroom::JoinCode::SYMBOLS.size
    assert_equal AddJoinCodeToClassrooms::ALPHABET.chars.sort, Entities::Classroom::JoinCode::SYMBOLS.sort
  end

  test "the database refuses a code out of format, a duplicate and a missing code" do
    first = create_classroom
    second = create_classroom

    refused = lambda do |error, value|
      assert_raises(error, value.inspect) do
        Orm::Classroom.transaction(requires_new: true) { Orm::Classroom.where(id: second.id).update_all(join_code: value) }
      end
    end
    [ "ABCDEF", "abcde", "abcdi2", "abcdo2", "abcd01", "abc-ef", "" ].each { refused.call(ActiveRecord::StatementInvalid, it) }
    refused.call(ActiveRecord::ValueTooLong, "abcdefg")
    refused.call(ActiveRecord::RecordNotUnique, first.join_code)
    refused.call(ActiveRecord::NotNullViolation, nil)
  end

  test "down removes the code with its index and its format; the classrooms keep their link" do
    classroom = create_classroom
    token = classroom.reload.link_token

    migrate(:down)

    assert_nil join_code_column
    assert_empty connection.indexes("classrooms").select { it.columns.include?("join_code") }
    assert_no_match(/join_code/, connection.check_constraints("classrooms").map(&:expression).join)
    assert_equal token, Orm::Classroom.find(classroom.id).link_token
  end

  test "the migration reruns both ways without failing" do
    migrate(:down)
    migrate(:down)

    assert_nil join_code_column

    migrate(:up)
    migrate(:up)

    assert join_code_column
    assert(Orm::Classroom.pluck(:join_code).all? { Entities::Classroom::JoinCode.valid?(it) })
  end
end

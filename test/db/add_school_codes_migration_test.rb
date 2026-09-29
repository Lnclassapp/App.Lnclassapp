require "test_helper"
require Rails.root.join("db/migrate/20260928110000_add_school_codes").to_s

# ADR-0057 (CE-09): the ~3 900 schools of production receive a school code each, in short batches, and the column
# becomes mandatory without a long lock.
class AddSchoolCodesMigrationTest < ActiveSupport::TestCase
  def connection = ActiveRecord::Base.connection

  test "the backfill gives every school without a code its own valid one, batch after batch, and keeps the others" do
    connection.change_column_null :schools, :school_code, true # rolled back with the test's transaction
    kept = create_school(school_code: "k7m4qz")
    drena = create_drena
    ids = Array.new(7) { create_school(drena:, name: "Lycée #{it}").id }
    Orm::School.where(id: ids).update_all(school_code: nil)

    AddSchoolCodes.new.backfill(batch_size: 3)

    codes = Orm::School.where(id: ids).pluck(:school_code)
    assert_equal 7, codes.compact.uniq.size
    assert(codes.all? { Entities::School::SchoolCode.valid?(it) }, codes.inspect)
    assert_not_includes codes, "k7m4qz"
    assert_equal "k7m4qz", kept.reload.school_code

    assert_no_changes -> { Orm::School.order(:id).pluck(:school_code) } do
      AddSchoolCodes.new.backfill(batch_size: 3)
    end
  end

  test "the generator of the migration draws the codes of the domain, outside the taken ones" do
    taken = Set["k7m4qz"]
    codes = AddSchoolCodes.new.draw(count: 50, taken:)

    assert_equal 50, codes.uniq.size
    assert(codes.all? { Entities::School::SchoolCode.valid?(it) })
    assert_equal 51, taken.size
  end
end

# The whole migration, down then up (twice), outside any transaction: CREATE INDEX CONCURRENTLY refuses one.
class AddSchoolCodesMigrationRunTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  def migrate(direction)
    changing_schema { ActiveRecord::Migration.suppress_messages { AddSchoolCodes.new.migrate(direction) } }
    Orm::School.reset_column_information
  end

  teardown do
    Orm::School.where(id: @school_ids).delete_all
    Orm::Drena.where(id: @drena_id).delete_all
  end

  test "down then up gives every existing school a code; running up again changes nothing" do
    drena = create_drena
    @drena_id = drena.id
    @school_ids = Array.new(3) { create_school(drena:, name: "Lycée #{it}").id }

    migrate(:down)
    assert_not Orm::School.column_names.include?("school_code")

    migrate(:up)
    codes = Orm::School.where(id: @school_ids).pluck(:school_code)
    assert_equal 3, codes.uniq.size
    assert(codes.all? { Entities::School::SchoolCode.valid?(it) })
    column = Orm::School.columns_hash["school_code"]
    assert_equal [ false, 6 ], [ column.null, column.limit ]
    assert(ActiveRecord::Base.connection.indexes("schools").any? { it.unique && it.columns == %w[school_code] })

    assert_no_changes -> { Orm::School.where(id: @school_ids).order(:id).pluck(:school_code) } do
      migrate(:up)
    end
  end
end

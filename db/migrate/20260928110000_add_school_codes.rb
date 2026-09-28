# ADR-0057: every school gets a school code, the key of the teacher's sign-up. ~3 900 schools in production: the
# column is added nullable, filled in batches of short transactions, indexed concurrently, then made mandatory through a
# validated check constraint, so that no step holds a lock that blocks writes on `schools` for long. Every step checks
# what already exists: an interrupted run resumes where it stopped.
class AddSchoolCodes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Frozen copy of Entities::School::SchoolCode at the time of this migration: a migration never depends on the domain,
  # which may change after it.
  SYMBOLS = ((("a".."z").to_a - %w[i o]) + ("2".."9").to_a).freeze
  LENGTH = 6
  FORMAT = "^[a-hj-np-z2-9]{6}$".freeze
  BATCH_SIZE = 500

  def up
    add_column :schools, :school_code, :string, limit: LENGTH, if_not_exists: true
    add_column :schools, :school_code_rotated_at, :datetime, if_not_exists: true
    backfill
    add_index :schools, :school_code, unique: true, algorithm: :concurrently, if_not_exists: true
    make_mandatory
    add_format_check
  end

  def down
    remove_column :schools, :school_code_rotated_at, if_exists: true
    remove_column :schools, :school_code, if_exists: true
  end

  # Each batch in its own transaction: the rows being updated are the only ones locked, for one short UPDATE.
  def backfill(batch_size: BATCH_SIZE)
    taken = select_values("SELECT school_code FROM schools WHERE school_code IS NOT NULL").to_set
    loop do
      ids = select_values("SELECT id FROM schools WHERE school_code IS NULL ORDER BY id LIMIT #{Integer(batch_size)}")
      break if ids.empty?

      values = ids.zip(draw(count: ids.size, taken:)).map { |id, code| "(#{Integer(id)}, #{quote(code)})" }.join(", ")
      transaction do
        execute "UPDATE schools SET school_code = batch.code FROM (VALUES #{values}) AS batch(id, code) " \
                "WHERE schools.id = batch.id AND schools.school_code IS NULL"
      end
    end
  end

  # → `count` distinct codes, absent from `taken` (Set), which they complete.
  def draw(count:, taken:)
    Array.new(count) do
      code = generate
      code = generate while taken.include?(code)
      taken << code
      code
    end
  end

  private

  def generate = Array.new(LENGTH) { SYMBOLS.sample(random: SecureRandom) }.join

  # PostgreSQL skips the full scan of SET NOT NULL when a validated CHECK already proves it.
  def make_mandatory
    return unless column_nullable?

    unless check_constraint_exists?(:schools, name: "schools_school_code_present")
      add_check_constraint :schools, "school_code IS NOT NULL", name: "schools_school_code_present", validate: false
    end
    validate_check_constraint :schools, name: "schools_school_code_present"
    change_column_null :schools, :school_code, false
    remove_check_constraint :schools, name: "schools_school_code_present"
  end

  # PostgreSQL rewrites the expression (casts): the constraint is recognised by its name only.
  def add_format_check
    unless check_constraint_exists?(:schools, name: "schools_school_code_format")
      add_check_constraint :schools, "school_code ~ '#{FORMAT}'", name: "schools_school_code_format", validate: false
    end
    validate_check_constraint :schools, name: "schools_school_code_format"
  end

  def column_nullable? = connection.columns(:schools).find { it.name == "school_code" }.null
end

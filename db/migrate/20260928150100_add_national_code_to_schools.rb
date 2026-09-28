# ADR-0063: the national code of a school (6 digits, public, printed with the BEPC results) designates it for a teacher
# sign-up without school code. Optional, unique when present. ~3 900 schools in production: the index is built
# concurrently and the check is validated apart, so that no step blocks writes on `schools`. Rerunnable.
class AddNationalCodeToSchools < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  CHECK = "schools_national_code_format".freeze

  def up
    add_column :schools, :national_code, :string, limit: 6, if_not_exists: true
    add_index :schools, :national_code, unique: true, where: "national_code IS NOT NULL", algorithm: :concurrently,
                                        if_not_exists: true
    unless check_constraint_exists?(:schools, name: CHECK)
      add_check_constraint :schools, "national_code ~ '^[0-9]{6}$'", name: CHECK, validate: false
    end
    validate_check_constraint :schools, name: CHECK
  end

  def down
    remove_column :schools, :national_code, if_exists: true
  end
end

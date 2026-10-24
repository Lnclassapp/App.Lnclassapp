# ADR-XXXX (code-de-classe-a-six-caracteres, §4 et §6): the classroom code comes back, 6 symbols, next to the link token.
# Three steps, rerunnable both ways: add the nullable column, fill the existing classrooms by batches with the domain
# generator, then NOT NULL, unique index and format constraint (lower case, no i, l, o, 0 or 1). Down removes the column with
# its index and its constraint: the codes are not kept, nothing reads them once the code is gone.
# The column also has a database default (6 symbols drawn from gen_random_uuid, which is cryptographic, like the link token's
# default), so a classroom written without a code (bulk insert, raw SQL) still gets a valid one; the app draws its own with
# the domain generator and its five attempts (Entities::Classroom::JoinCode).
class AddJoinCodeToClassrooms < ActiveRecord::Migration[8.1]
  FORMAT = "join_code ~ '^[a-hjkmnp-z2-9]{6}$'".freeze
  CHECK = "classrooms_join_code_format".freeze
  BATCH = 500
  ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789".freeze
  # Two random bytes per symbol (each from a fresh uuid), modulo 31: 65536 = 2114 × 31 + 2, so the bias is 2 in 65536, negligible.
  DRAW = "((get_byte(uuid_send(gen_random_uuid()), 0) * 256 + get_byte(uuid_send(gen_random_uuid()), 1)) % 31) + 1".freeze
  DEFAULT_SQL = Array.new(6) { "substr('#{ALPHABET}', #{DRAW}, 1)" }.join(" || ").freeze

  def up
    add_column :classrooms, :join_code, :string, limit: 6, if_not_exists: true
    change_column :classrooms, :join_code, :string, limit: 6
    remove_check_constraint :classrooms, name: CHECK, if_exists: true
    # A code of the former format (5 symbols, ADR-0085) is no code: it is drawn again like a missing one.
    execute "UPDATE classrooms SET join_code = NULL WHERE join_code IS NOT NULL AND join_code !~ '^[a-hjkmnp-z2-9]{6}$'"
    fill_missing_codes
    change_column_null :classrooms, :join_code, false
    change_column_default :classrooms, :join_code, from: nil, to: -> { DEFAULT_SQL }
    add_index :classrooms, :join_code, unique: true, if_not_exists: true
    add_check_constraint :classrooms, FORMAT, name: CHECK, if_not_exists: true
  end

  def down
    remove_check_constraint :classrooms, name: CHECK, if_exists: true
    remove_index :classrooms, :join_code, if_exists: true
    remove_column :classrooms, :join_code, if_exists: true
  end

  private

  def fill_missing_codes
    taken = select_values("SELECT join_code FROM classrooms WHERE join_code IS NOT NULL").to_set
    loop do
      ids = select_values("SELECT id FROM classrooms WHERE join_code IS NULL ORDER BY id LIMIT #{BATCH}")
      break if ids.empty?

      rows = ids.map do |id|
        code = Entities::Classroom::JoinCode.generate_free { taken.include?(it) }
        taken << code
        "(#{Integer(id)}, #{connection.quote(code)})"
      end
      execute "UPDATE classrooms SET join_code = v.code FROM (VALUES #{rows.join(', ')}) AS v(id, code) WHERE classrooms.id = v.id"
    end
  end
end

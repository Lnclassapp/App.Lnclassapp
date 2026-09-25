require "test_helper"

# The database is the last line of defence (ADR-0027, ADR-0029, ADR-0036, ADR-0039) :
# every uniqueness, every enumeration and every foreign key rule of the V1 schema is
# checked here against the live test database, not against the migration files.
class SchemaConstraintsTest < ActiveSupport::TestCase
  # Entities::Classroom::JoinCode::LENGTH once the domain lands (Lot 0.4).
  JOIN_CODE_LENGTH = defined?(Entities::Classroom::JoinCode::LENGTH) ? Entities::Classroom::JoinCode::LENGTH : 5

  PUBLIC_ID_TABLES = %w[users drenas schools classrooms classroom_assignments exercises exercise_sessions
                        knowledge_gaps import_reports].freeze
  SLUG_TABLES = %w[drenas levels series materials courses essentials].freeze

  # table => [[columns], where] for every unique index beyond public_id and slug. The
  # condition is compared without casts, parentheses nor spaces: PostgreSQL rewrites it.
  UNIQUE_INDEXES = {
    "users" => [ [ %w[contact], "contactISNOTNULL" ] ],
    "teacher_profiles" => [ [ %w[user_id], nil ] ],
    "sessions" => [ [ %w[token_digest], nil ] ],
    "totp_credentials" => [ [ %w[user_id], nil ] ],
    "pin_recovery_codes" => [ [ %w[user_id], "used_atISNULLANDrevoked_atISNULL" ] ],
    "invitations" => [ [ %w[token_digest], nil ], [ %w[kind contact], "accepted_atISNULLANDrevoked_atISNULL" ] ],
    "drenas" => [ [ %w[name], nil ] ],
    "schools" => [ [ %w[drena_id name], nil ] ],
    "teacher_schools" => [ [ %w[teacher_id school_id], nil ], [ %w[teacher_id], "primary" ] ],
    "levels" => [ [ %w[name], nil ], [ %w[position], nil ] ],
    "series" => [ [ %w[name], nil ] ],
    "level_series" => [ [ %w[level_id series_id], nil ] ],
    "materials" => [ [ %w[name], nil ], [ %w[shortname], nil ] ],
    "classrooms" => [ [ %w[school_id school_year name], nil ], [ %w[join_code], "join_codeISNOTNULL" ] ],
    "classroom_students" => [ [ %w[classroom_id student_id], nil ], [ %w[student_id], "primaryANDleft_atISNULL" ] ],
    "teacher_classrooms" => [ [ %w[teacher_id classroom_id], nil ] ],
    "courses" => [ [ %w[level_id material_id name], "series_idISNULL" ],
                   [ %w[level_id material_id series_id name], "series_idISNOTNULL" ] ],
    "essentials" => [ [ %w[course_id name], nil ], [ %w[course_id position], nil ] ],
    "exercises" => [ [ %w[essential_id position], nil ] ],
    "questions" => [ [ %w[exercise_id position], nil ] ],
    "answers" => [ [ %w[question_id position], nil ] ],
    "classroom_assignments" => [ [ %w[classroom_id assignable_type assignable_id], "status='active'" ] ],
    "exercise_sessions" => [ [ %w[student_id exercise_id], "status='started'" ] ],
    "question_attempts" => [ [ %w[exercise_session_id question_id], nil ] ],
    "exercise_badges" => [ [ %w[student_id exercise_id], nil ] ],
    "knowledge_gaps" => [ [ %w[student_id essential_id], "status='pending'" ] ],
    "import_reports" => [ [ %w[kind], "status=ANYARRAY['queued','validating','importing']" ],
                          [ %w[kind checksum_sha256], "status='completed'" ] ]
  }.freeze

  # table => { column => allowed values } for every string enumeration.
  ENUMERATIONS = {
    "users" => { "gender" => %w[male female], "role" => %w[student teacher school_admin team], "team_role" => %w[admin content field] },
    "login_attempts" => { "kind" => %w[pin second_factor] },
    "invitations" => { "kind" => %w[team school_staff], "team_role" => %w[admin content field],
                       "position" => %w[principal censor educator secretary] },
    "schools" => { "school_type" => %w[public private mixed], "cycle" => %w[first both], "status" => %w[draft active inactive] },
    "levels" => { "cycle" => %w[first second] },
    "materials" => { "category" => %w[literature science other] },
    "classrooms" => { "status" => %w[active archived] },
    "courses" => { "status" => %w[draft published archived] },
    "essentials" => { "status" => %w[draft published archived] },
    "exercises" => { "status" => %w[draft published archived], "exercise_type" => %w[fixation evaluation] },
    "questions" => { "question_type" => %w[true_false single_choice multiple_correct_2 multiple_correct_3] },
    "classroom_assignments" => { "status" => %w[active archived], "assignable_type" => %w[Course Essential Exercise] },
    "exercise_sessions" => { "status" => %w[started completed abandoned], "kind" => %w[standard remediation] },
    "exercise_badges" => { "level" => %w[bronze silver gold diamond] },
    "knowledge_gaps" => { "status" => %w[pending remediated self_corrected] },
    "import_reports" => { "kind" => %w[schools course_tree essentials exercises],
                          "status" => %w[queued validating importing completed rejected failed] }
  }.freeze

  # ADR-0036 : the closed list of cascades, from a parent to its technical rows.
  CASCADES = %w[sessions login_attempts totp_credentials backup_codes pin_recovery_codes].freeze
  FRAMEWORK_TABLES = /\A(active_storage_|solid_(queue|cache|cable)_|schema_migrations|ar_internal_metadata)/

  def connection = ActiveRecord::Base.connection

  def application_tables = connection.tables.grep_v(FRAMEWORK_TABLES)

  def unique_indexes(table)
    connection.indexes(table).select(&:unique).map { |index| [ index.columns, index.where&.gsub(/::[\w ]+(\[\])?|[()"\s]/, "") ] }
  end

  def check_expressions(table) = connection.check_constraints(table).map(&:expression).join("\n")

  test "the join code column is exactly as long as the generated code" do
    assert_equal JOIN_CODE_LENGTH, connection.columns("classrooms").find { |column| column.name == "join_code" }.limit
  end

  test "every exposed table has a 14 character public_id with a unique index" do
    PUBLIC_ID_TABLES.each do |table|
      column = connection.columns(table).find { |candidate| candidate.name == "public_id" }

      assert_equal [ 14, false ], [ column&.limit, column&.null ], table
      assert_includes unique_indexes(table), [ %w[public_id], nil ], table
    end
  end

  test "every catalog table has a mandatory slug with a unique index" do
    SLUG_TABLES.each do |table|
      assert_not connection.columns(table).find { |column| column.name == "slug" }.null, table
      assert_includes unique_indexes(table), [ %w[slug], nil ], table
    end
  end

  test "every unique and partial unique index is in place" do
    UNIQUE_INDEXES.each do |table, expected|
      expected.each { |index| assert_includes unique_indexes(table), index, table }
    end
  end

  test "every enumeration is a string column guarded by a check on its values" do
    ENUMERATIONS.each do |table, columns|
      columns.each do |column, values|
        assert_equal :string, connection.columns(table).find { |candidate| candidate.name == column }.type, "#{table}.#{column}"
        assert_match(/\b#{column}\b.*#{values.map { |value| "'#{value}'" }.join('.*')}/m, check_expressions(table), "#{table}.#{column}")
      end
    end
  end

  test "every primary key is a bigint" do
    application_tables.each do |table|
      assert_equal :integer, connection.columns(table).find { |column| column.name == "id" }.type, table
      assert_equal 8, connection.columns(table).find { |column| column.name == "id" }.limit, table
    end
  end

  test "every foreign key restricts deletion, except the closed list of cascades" do
    application_tables.each do |table|
      connection.foreign_keys(table).each do |foreign_key|
        expected = CASCADES.include?(table) && foreign_key.to_table == "users" && foreign_key.column == "user_id" ? :cascade : :restrict

        assert_equal expected, foreign_key.on_delete, "#{table}.#{foreign_key.column}"
      end
    end
  end

  test "every person column references users" do
    application_tables.each do |table|
      connection.columns(table).map(&:name).grep(/\A(author|student|teacher|actor|user|\w+_by|accepted_user)_id\z/).each do |column|
        assert_equal "users", connection.foreign_keys(table).find { |foreign_key| foreign_key.column == column }&.to_table, "#{table}.#{column}"
      end
    end
  end

  test "a question attempt is immutable, it has no timestamps" do
    columns = connection.columns("question_attempts").map(&:name)

    assert_not_includes columns, "updated_at"
    assert_not_includes columns, "created_at"
  end

  test "the database refuses what the application must never write" do
    violations = {
      "a team account without sub-role" => "INSERT INTO users (public_id, last_name, first_name, gender, role, pin_digest, created_at, updated_at) VALUES ('abcdefghijklmn', 'K', 'A', 'male', 'team', 'x', now(), now())",
      "a contact that is not ivorian" => "INSERT INTO users (public_id, last_name, first_name, contact, gender, role, pin_digest, created_at, updated_at) VALUES ('abcdefghijklmn', 'K', 'A', '0912345678', 'male', 'student', 'x', now(), now())",
      "a school year that skips a year" => "INSERT INTO classrooms (public_id, school_id, level_id, name, school_year, created_at, updated_at) VALUES ('abcdefghijklmn', 1, 1, '6ème 1', '2026-2028', now(), now())"
    }

    violations.each do |label, sql|
      assert_raises(ActiveRecord::CheckViolation, label) { connection.transaction(requires_new: true) { connection.execute(sql) } }
    end
  end
end

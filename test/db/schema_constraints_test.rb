require "test_helper"

# The database is the last line of defence (ADR-0027, ADR-0029, ADR-0036, ADR-0039) :
# every uniqueness, every enumeration and every foreign key rule of the V1 schema is
# checked here against the live test database, not against the migration files.
class SchemaConstraintsTest < ActiveSupport::TestCase
  # Entities::Classroom::JoinCode::LENGTH once the domain lands (Lot 0.4).
  JOIN_CODE_LENGTH = defined?(Entities::Classroom::JoinCode::LENGTH) ? Entities::Classroom::JoinCode::LENGTH : 5

  PUBLIC_ID_TABLES = %w[users drenas schools classrooms classroom_assignments exercises exercise_sessions
                        knowledge_gaps import_reports school_join_requests articles article_images].freeze
  SLUG_TABLES = %w[drenas levels series materials courses essentials articles].freeze

  # table => [[columns], where] for every unique index beyond public_id and slug. The
  # condition is compared without casts, parentheses nor spaces: PostgreSQL rewrites it.
  UNIQUE_INDEXES = {
    "users" => [ [ %w[contact], "contactISNOTNULL" ] ],
    "teacher_profiles" => [ [ %w[user_id], nil ], [ %w[referral_token], nil ] ],
    "referrals" => [ [ %w[referee_id], nil ] ],
    "school_join_requests" => [ [ %w[teacher_id], nil ] ],
    "sessions" => [ [ %w[token_digest], nil ] ],
    "totp_credentials" => [ [ %w[user_id], nil ] ],
    "pin_recovery_codes" => [ [ %w[user_id], "used_atISNULLANDrevoked_atISNULL" ] ],
    "invitations" => [ [ %w[token_digest], nil ], [ %w[kind contact], "accepted_atISNULLANDrevoked_atISNULL" ] ],
    "drenas" => [ [ %w[name], nil ] ],
    "schools" => [ [ %w[drena_id name], nil ], [ %w[school_code], nil ], [ %w[national_code], "national_codeISNOTNULL" ] ],
    "teacher_schools" => [ [ %w[teacher_id school_id], nil ], [ %w[teacher_id], "primary" ] ],
    "school_staffs" => [ [ %w[user_id], nil ] ],
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
    "import_reports" => [ [ %w[kind], "status=ANYARRAY['queued','validating','importing']" ] ],
    "classroom_plan_entries" => [ [ %w[school_type level_id series_id], "series_idISNOTNULL" ], [ %w[school_type level_id], "series_idISNULL" ] ],
    "teacher_school_departures" => [ [ %w[teacher_id school_id], "reinstated_atISNULL" ] ]
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
    "classroom_assignments" => { "status" => %w[active archived], "assignable_type" => %w[Exercise] }, # ADR-0072 §4.1
    "exercise_sessions" => { "status" => %w[started completed abandoned], "kind" => %w[standard remediation] },
    "exercise_badges" => { "level" => %w[bronze silver gold diamond] },
    "knowledge_gaps" => { "status" => %w[pending remediated self_corrected] },
    "referrals" => { "source" => %w[link sponsor] },
    "referral_shares" => { "channel" => %w[whatsapp sms copy native] },
    "school_join_requests" => { "status" => %w[pending approved rejected], "decided_via" => %w[team sponsor] },
    "import_reports" => { "kind" => %w[schools course_tree essentials exercises classrooms drenas],
                          "status" => %w[queued validating importing completed rejected failed] },
    "classroom_plan_entries" => { "school_type" => %w[public private] },
    "articles" => { "status" => %w[draft published archived], "signature" => %w[team author] }, # ADR-0074 §4.1
    "article_images" => { "content_type" => %w[image/jpeg image/png image/webp] }
  }.freeze

  # ADR-0036 : the closed list of cascades, from a parent to its technical rows.
  CASCADES = %w[sessions login_attempts totp_credentials backup_codes pin_recovery_codes].freeze
  FRAMEWORK_TABLES = /\A(active_storage_|action_text_|solid_(queue|cache|cable)_|schema_migrations|ar_internal_metadata)/

  def connection = ActiveRecord::Base.connection

  def application_tables = connection.tables.grep_v(FRAMEWORK_TABLES)

  def unique_indexes(table)
    connection.indexes(table).select(&:unique).map { |index| [ index.columns, index.where&.gsub(/::[\w ]+(\[\])?|[()"\s]/, "") ] }
  end

  def check_expressions(table) = connection.check_constraints(table).map(&:expression).join("\n")

  test "the join code column is exactly as long as the generated code" do
    assert_equal JOIN_CODE_LENGTH, connection.columns("classrooms").find { |column| column.name == "join_code" }.limit
  end

  test "CE-09: every school has a school code of exactly 6 symbols, unique, in the documented alphabet (ADR-0057)" do
    column = connection.columns("schools").find { |candidate| candidate.name == "school_code" }

    assert_equal [ Entities::School::SchoolCode::LENGTH, false ], [ column.limit, column.null ]
    assert_match(/school_code.*\[a-hj-np-z2-9\]\{6\}/, check_expressions("schools"))
    assert connection.columns("schools").find { |candidate| candidate.name == "school_code_rotated_at" }.null
  end

  test "CE-09: the database refuses a school without code, with a malformed one or with one already taken" do
    drena_id = create_drena.id
    insert = lambda do |code, name|
      connection.execute("INSERT INTO schools (public_id, drena_id, name, school_type, school_code, created_at, updated_at) " \
                         "VALUES ('#{SecureRandom.base58(14)}', #{drena_id}, '#{name}', 'public', #{code}, now(), now())")
    end
    insert.call("'k7m4qz'", "Lycée A")

    {
      ActiveRecord::NotNullViolation => [ "NULL", "Lycée B" ],
      ActiveRecord::CheckViolation => [ "'K7M4QZ'", "Lycée C" ],
      ActiveRecord::RecordNotUnique => [ "'k7m4qz'", "Lycée D" ]
    }.each do |error, (code, name)|
      assert_raises(error, code) { connection.transaction(requires_new: true) { insert.call(code, name) } }
    end
    assert_raises(ActiveRecord::CheckViolation) { connection.transaction(requires_new: true) { insert.call("'k7m4q0'", "Lycée E") } }
  end

  test "CP-01: every teacher profile draws its own opaque referral token of 12 hexadecimal characters (ADR-0063)" do
    tokens = Array.new(3) { create_teacher.teacher_profile.reload.referral_token }

    assert_equal 3, tokens.uniq.size
    assert(tokens.all? { it.match?(/\A[0-9a-f]{12}\z/) }, tokens.inspect)
    profile = create_teacher.teacher_profile
    assert_raises(ActiveRecord::CheckViolation) { connection.transaction(requires_new: true) { profile.update_column(:referral_token, "ABC") } }
    assert_raises(ActiveRecord::RecordNotUnique) do
      connection.transaction(requires_new: true) { profile.update_column(:referral_token, tokens.first) }
    end
  end

  test "CP-02: a referee has one referrer, never themself" do
    referrer = create_teacher
    referee = create_teacher
    school_id = Orm::TeacherSchool.find_by!(teacher: referrer).school_id
    Orm::Referral.create!(referrer:, referee:, school_id:, source: "link", created_at: Time.current)

    assert_raises(ActiveRecord::RecordNotUnique) do
      connection.transaction(requires_new: true) { Orm::Referral.create!(referrer: create_teacher, referee:, school_id:, source: "link") }
    end
    assert_raises(ActiveRecord::CheckViolation) do
      connection.transaction(requires_new: true) { Orm::Referral.create!(referrer:, referee: referrer, school_id:, source: "link") }
    end
  end

  test "CP-09: a national code is 6 digits, unique when present, optional" do
    create_school(national_code: nil)
    create_school(national_code: nil)
    create_school(national_code: "012345")

    assert_raises(ActiveRecord::RecordNotUnique) { connection.transaction(requires_new: true) { create_school(national_code: "012345") } }
    assert_raises(ActiveRecord::CheckViolation) { connection.transaction(requires_new: true) { create_school(national_code: "12345") } }
    assert_raises(ActiveRecord::CheckViolation) { connection.transaction(requires_new: true) { create_school(national_code: "12345a") } }
  end

  test "CP-11: a join request is decided exactly when it is no longer pending" do
    request = create_join_request

    assert_raises(ActiveRecord::CheckViolation) { connection.transaction(requires_new: true) { request.update_columns(status: "approved") } }
    assert_raises(ActiveRecord::CheckViolation) do
      connection.transaction(requires_new: true) { request.update_columns(decided_at: Time.current) }
    end
    request.update_columns(status: "rejected", decided_at: Time.current, decided_via: "team")
    assert_equal "rejected", request.reload.status
  end

  # ADR-0065 : un établissement par compte de direction ; une invitation de direction a une école, pas de fonction.
  test "DS-03: a school admin is attached to one school only" do
    school = create_school
    admin = create_school_admin(school:)

    assert_raises(ActiveRecord::RecordNotUnique) { Orm::SchoolStaff.create!(user: admin, school: create_school) }
    assert_equal %w[created_at id invited_by_id school_id user_id], connection.columns("school_staffs").map(&:name).sort
  end

  test "DS-01: a school staff invitation needs a school, not a position" do
    school = create_school

    assert_nil create_invitation(kind: "school_staff", school:, position: nil).position
    assert_raises(ActiveRecord::CheckViolation) do
      Orm::Invitation.transaction(requires_new: true) do
        Orm::Invitation.create!(kind: "school_staff", contact: "0700000009", token_digest: "x" * 64, expires_at: 1.day.from_now)
      end
    end
  end

  # ADR-0071 §4.4 : un retrait d'enseignant reste ouvert jusqu'à sa réintégration ; un seul ouvert par couple.
  test "GD: a teacher has one open departure per school, reinstated by someone at some time, both or neither" do
    school = create_school
    teacher = create_teacher(school: nil)
    admin = create_school_admin(school:)
    departure = create_teacher_departure(teacher:, school:, detached_by: admin)

    assert_raises(ActiveRecord::RecordNotUnique) do
      connection.transaction(requires_new: true) { create_teacher_departure(teacher:, school:, detached_by: admin) }
    end
    assert_raises(ActiveRecord::CheckViolation) do
      connection.transaction(requires_new: true) { departure.update_columns(reinstated_at: Time.current) }
    end
    assert_raises(ActiveRecord::CheckViolation) do
      connection.transaction(requires_new: true) { departure.update_columns(reinstated_by_id: admin.id) }
    end
    departure.update_columns(reinstated_at: Time.current, reinstated_by_id: admin.id)
    create_teacher_departure(teacher:, school:, detached_by: admin)
    create_teacher_departure(teacher:, school: create_school, detached_by: admin)

    assert_equal 3, Orm::TeacherSchoolDeparture.where(teacher:).count
    assert_includes connection.indexes("teacher_school_departures").map(&:columns), %w[school_id detached_at]
  end

  test "GD: a departure keeps its teacher, its school and the people who acted on it (RESTRICT)" do
    expected = { "teacher_id" => "users", "school_id" => "schools", "detached_by_id" => "users", "reinstated_by_id" => "users" }
    foreign_keys = connection.foreign_keys("teacher_school_departures")

    assert_equal expected, foreign_keys.to_h { [ it.column, it.to_table ] }
    assert(foreign_keys.all? { it.on_delete == :restrict })
    assert_equal %w[detached_at detached_by_id school_id teacher_id],
                 connection.columns("teacher_school_departures").reject(&:null).map(&:name).without("id").sort

    # Nothing else references these two rows: only the departure holds them.
    school = create_school
    teacher = create_user(role: "teacher")
    create_teacher_departure(teacher:, school:, detached_by: create_user(role: "school_admin"))
    assert_raises(ActiveRecord::InvalidForeignKey) { connection.transaction(requires_new: true) { Orm::User.where(id: teacher.id).delete_all } }
    assert_raises(ActiveRecord::InvalidForeignKey) { connection.transaction(requires_new: true) { Orm::School.where(id: school.id).delete_all } }
  end

  # ADR-0074 §4.1 : un article, ses images ; la base refuse ce que le domaine refuse déjà.
  test "BL: the database refuses an article or an image the blog must never hold" do
    author = create_team_member(team_role: "content", second_factor: false)
    article = lambda do |**columns|
      Orm::Article.insert!({ public_id: SecureRandom.base58(14), slug: "a-#{SecureRandom.hex(4)}", title: "Réviser",
                             author_id: author.id, created_at: Time.current, updated_at: Time.current, **columns })
    end
    image = lambda do |**columns|
      Orm::ArticleImage.insert!({ public_id: SecureRandom.base58(14), content_type: "image/jpeg", byte_size: 1000,
                                  width: 1600, height: 900, created_at: Time.current, updated_at: Time.current, **columns })
    end
    article.call
    image.call
    article.call(status: "published", excerpt: "Un plan.", published_at: Time.current)
    article.call(status: "archived", excerpt: "Un plan.", published_at: Time.current, archived_at: Time.current)
    image.call(byte_size: 1_048_576, width: 1, height: 1)

    {
      "a status in French" => -> { article.call(status: "publié") },
      "an unknown signature" => -> { article.call(signature: "x") },
      "a blank title" => -> { article.call(title: "  ") },
      "a published article without excerpt" => -> { article.call(status: "published", excerpt: " ", published_at: Time.current) },
      "a published article without date" => -> { article.call(status: "published", excerpt: "Un plan.") },
      "an archived article without archived_at" => -> { article.call(status: "archived", excerpt: "Un plan.", published_at: Time.current) },
      "an archive date on a draft" => -> { article.call(archived_at: Time.current) },
      "a negative reads count" => -> { article.call(reads_count: -1) },
      "an image of 1601 px" => -> { image.call(width: 1601) },
      "an image of 0 px" => -> { image.call(height: 0) },
      "a GIF" => -> { image.call(content_type: "image/gif") },
      "an empty file" => -> { image.call(byte_size: 0) },
      "1 MB and 1 byte" => -> { image.call(byte_size: 1_048_577) }
    }.each do |label, insert|
      assert_raises(ActiveRecord::CheckViolation, label) { connection.transaction(requires_new: true) { insert.call } }
    end
  end

  test "BL: an article and its images keep their author, their article and their cover (RESTRICT)" do
    assert_equal({ "author_id" => "users", "cover_image_id" => "article_images" },
                 connection.foreign_keys("articles").to_h { [ it.column, it.to_table ] })
    assert_equal({ "article_id" => "articles" }, connection.foreign_keys("article_images").to_h { [ it.column, it.to_table ] })
    assert((connection.foreign_keys("articles") + connection.foreign_keys("article_images")).all? { it.on_delete == :restrict })
    assert_equal({ "slug" => 140, "title" => 120, "excerpt" => 200, "cover_alt" => 150 },
                 connection.columns("articles").select { it.limit && it.type == :string }.to_h { [ it.name, it.limit ] }.except("public_id"))
    assert_equal 150, connection.columns("article_images").find { it.name == "alt" }.limit
    assert_equal [ [ %w[published_at id], "status='published'" ] ],
                 connection.indexes("articles").reject(&:unique).filter_map { [ it.columns, it.where&.gsub(/::[\w ]+|[()"\s]/, "") ] if it.where }
    assert_includes connection.indexes("articles").map(&:columns), %w[author_id]
    assert_not connection.indexes("articles").any? { it.columns.include?("reads_count") }
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

  test "an import file may be imported again: only one running import per kind is unique" do
    assert_equal [ [ %w[kind], UNIQUE_INDEXES["import_reports"].first.last ], [ %w[public_id], nil ] ],
                 unique_indexes("import_reports").sort_by { |columns, _| columns }
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

  test "levels and series have no code column: the frozen slug is the code" do
    %w[levels series].each { |table| assert_not_includes connection.columns(table).map(&:name), "code", table }
  end

  test "friendly_id leaves no table behind" do
    assert_not connection.table_exists?("friendly_id_slugs")
  end

  test "course and essential content lives in Action Text, once per record and field" do
    assert_includes unique_indexes("action_text_rich_texts"), [ %w[record_type record_id name], nil ]
    %w[courses essentials].each { |table| assert_not_includes connection.columns(table).map(&:name), "content", table }
  end

  test "the database refuses what the application must never write" do
    violations = {
      "a team account without sub-role" => "INSERT INTO users (public_id, last_name, first_name, gender, role, pin_digest, created_at, updated_at) VALUES ('abcdefghijklmn', 'K', 'A', 'male', 'team', 'x', now(), now())",
      "a contact that is not ivorian" => "INSERT INTO users (public_id, last_name, first_name, contact, gender, role, pin_digest, created_at, updated_at) VALUES ('abcdefghijklmn', 'K', 'A', '0912345678', 'male', 'student', 'x', now(), now())",
      "a school year that skips a year" => "INSERT INTO classrooms (public_id, school_id, level_id, name, school_year, created_at, updated_at) VALUES ('abcdefghijklmn', 1, 1, '6ème 1', '2026-2028', now(), now())",
      "an import without the checksum of its file" => "INSERT INTO import_reports (public_id, kind, status, imported_by_id, created_at, updated_at) VALUES ('abcdefghijklmo', 'schools', 'queued', 1, now(), now())",
      "a completed import whose counts do not add up" => "INSERT INTO import_reports (public_id, kind, status, checksum_sha256, total_count, imported_count, imported_by_id, created_at, updated_at) VALUES ('abcdefghijklmn', 'schools', 'completed', 'x', 3, 2, 1, now(), now())"
    }

    violations.each do |label, sql|
      assert_raises(ActiveRecord::CheckViolation, label) { connection.transaction(requires_new: true) { connection.execute(sql) } }
    end
  end
end

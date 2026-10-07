require "test_helper"
require Rails.root.join("db/migrate/20261007100000_add_teacher_arrival_and_school_invite_tokens").to_s

# ADR-0082 §4.1, §4.2 (IE-14): on a live database, every existing teacher receives an arrival channel deduced from what
# is known of him (a link referral, then a join request, else the school code), and every existing school its two
# invite tokens. Each test runs in the rolled back transaction of the test: PostgreSQL rolls the columns back with it.
class AddTeacherArrivalAndSchoolInviteTokensMigrationTest < ActiveSupport::TestCase
  def connection = ActiveRecord::Base.connection

  def migrate(direction)
    changing_schema do
      ActiveRecord::Migration.suppress_messages { AddTeacherArrivalAndSchoolInviteTokens.new.migrate(direction) }
    end
    [ Orm::TeacherProfile, Orm::School ].each(&:reset_column_information)
  end

  def channels(teachers) = teachers.transform_values { Orm::TeacherProfile.find_by!(user_id: it.id).joined_via }

  teardown { [ Orm::TeacherProfile, Orm::School ].each(&:reset_column_information) }

  test "IE-14: a link referral gives colleague, then a join request gives standard, otherwise code" do
    linked = create_teacher
    create_referral(referee: linked)
    linked_and_requested = create_teacher
    create_referral(referee: linked_and_requested)
    create_join_request(teacher: linked_and_requested, status: "approved")
    sponsored = create_teacher
    create_referral(referee: sponsored, source: "sponsor")
    create_join_request(teacher: sponsored, status: "approved")
    refused = create_join_request(status: "rejected").teacher_id
    teachers = { linked:, linked_and_requested:, sponsored:, refused: Orm::User.find(refused), by_code: create_teacher }

    migrate(:down)
    assert_not Orm::TeacherProfile.column_names.include?("joined_via")

    migrate(:up)
    assert_equal({ linked: "colleague", linked_and_requested: "colleague", sponsored: "standard", refused: "standard",
                   by_code: "code" }, channels(teachers))
    column = Orm::TeacherProfile.columns_hash["joined_via"]
    assert_equal [ false, nil ], [ column.null, column.default ], "plus de défaut après la reprise"
  end

  test "IE-14: every existing school receives its own direction and team tokens, 12 hexadecimal characters" do
    school_ids = Array.new(3) { create_school.id }

    migrate(:down)
    assert_empty Orm::School.column_names & %w[direction_invite_token team_invite_token]

    migrate(:up)
    tokens = Orm::School.where(id: school_ids).pluck(:direction_invite_token, :team_invite_token).flatten
    assert_equal 6, tokens.uniq.size
    assert(tokens.all? { it.match?(/\A[0-9a-f]{12}\z/) }, tokens.inspect)
    %w[direction_invite_token team_invite_token].each do |name|
      assert_equal [ false, 12 ], Orm::School.columns_hash[name].then { [ it.null, it.limit ] }, name
      assert(connection.indexes(:schools).any? { it.unique && it.columns == [ name ] }, name)
    end
  end

  test "running up again changes no token and no channel already written" do
    school = create_school
    teacher = create_teacher(school:)
    Orm::TeacherProfile.where(user_id: teacher.id).update_all(joined_via: "direction")
    create_join_request(teacher:, status: "approved")

    assert_no_changes -> { [ school.reload.attributes.slice("direction_invite_token", "team_invite_token"), channels(t: teacher) ] } do
      migrate(:up)
    end
  end

  test "running up again deduces nothing: a teacher still on code with a join request made after the migration keeps code" do
    requested = create_teacher(school: nil, joined_via: "code")
    create_join_request(teacher: requested)
    linked = create_teacher(joined_via: "code")
    create_referral(referee: linked)

    migrate(:up)

    assert_equal({ requested: "code", linked: "code" }, channels(requested:, linked:))
  end
end

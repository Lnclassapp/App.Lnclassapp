require "test_helper"

# ID-15, F-07 (ADR-0031, ADR-0032, UDR-0020): the team finds one account by its exact number, typed in any Ivorian
# form; no directory, no partial match, no PIN nor contact in the row.
class Queries::Identity::AccountLookupQueryTest < ActiveSupport::TestCase
  setup do
    @viewer = create_team_member
  end

  def lookup(contact) = Queries::Identity::AccountLookupQuery.new.call(contact:, viewer_id: @viewer.id)

  test "a student is found by the exact number, in any form, with their active classroom" do
    classroom = create_classroom(name: "6ème 2")
    student = create_student(classroom:, contact: "0511223344", first_name: "Awa", last_name: "Koné")

    [ "0511223344", "05 11 22 33 44", "+225 0511223344", "00225 05.11.22.33.44" ].each do |typed|
      assert_equal Queries::Identity::AccountLookupQuery::Row.new(
        public_id: student.public_id, display_name: "Awa Koné", role: :student, team_role: nil, classroom_name: "6ème 2",
        second_factor_confirmed: false, own_account: false
      ), lookup(typed)
    end
  end

  test "a student who left their classroom, and a teacher, have no classroom" do
    student = create_student(classroom: create_classroom, contact: "0100000001")
    Orm::ClassroomStudent.where(student:).update_all(left_at: Time.current)
    create_teacher(contact: "0500000002", classrooms: [ create_classroom ])

    assert_nil lookup("0100000001").classroom_name
    assert_equal [ :teacher, nil ], lookup("0500000002").then { [ it.role, it.classroom_name ] }
  end

  test "a team member tells their sub-role and whether their second factor is confirmed" do
    member = create_team_member(team_role: "content", contact: "0700000003")
    pending = create_team_member(team_role: "field", contact: "0700000004", second_factor: false)
    Orm::TotpCredential.create!(user: pending, secret: ROTP::Base32.random)

    assert_equal [ :team, "content", true ], lookup(member.contact).then { [ it.role, it.team_role, it.second_factor_confirmed ] }
    assert_equal [ "field", false ], lookup(pending.contact).then { [ it.team_role, it.second_factor_confirmed ] }
  end

  test "the viewer's own account is marked" do
    assert lookup(@viewer.contact).own_account
  end

  test "an unknown, partial, malformed or blank number gives nil" do
    create_student(contact: "0511223344")

    [ "0511223345", "051122334", "05112233", "0811223344", "", nil ].each { assert_nil lookup(it) }
  end

  test "the row reveals neither the number, nor the PIN, nor the internal id" do
    student = create_student(contact: "0511223344")

    assert_equal %i[public_id display_name role team_role classroom_name second_factor_confirmed own_account],
                 Queries::Identity::AccountLookupQuery::Row.members
    assert_not_includes lookup("0511223344").to_h.values, student.id
  end
end

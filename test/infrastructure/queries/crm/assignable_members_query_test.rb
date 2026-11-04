require "test_helper"

# ADR-XXXX (contexte crm) §4, UDR bloc « Suivi »: the owner of a school and the recipient of a follow-up are admin or field
# members of the team who are not anonymized.
class Queries::Crm::AssignableMembersQueryTest < ActiveSupport::TestCase
  def members = Queries::Crm::AssignableMembersQuery.new.call

  test "admin and field members are listed with their public id and name, sorted by displayed name" do
    zoe = create_team_member(team_role: "field", first_name: "Zoé", last_name: "Bamba")
    aya = create_team_member(team_role: "admin", first_name: "Aya", last_name: "Kouassi")

    assert_equal [ aya.id, zoe.id ], members.map(&:user_id)
    assert_equal [ aya.public_id, zoe.public_id ], members.map(&:public_id)
    assert_equal "Aya Kouassi", members.first.name
  end

  test "content members, teachers, students and direction are never listed" do
    create_team_member(team_role: "content")
    create_teacher
    create_student
    create_school_admin

    assert_empty members
  end

  test "an anonymized member is left out" do
    create_team_member(team_role: "field", anonymized_at: Time.current)

    assert_empty members
  end

  test "a member without a verified second factor is still assignable" do
    member = create_team_member(second_factor: false)

    assert_equal [ member.id ], members.map(&:user_id)
  end
end

require "test_helper"

# ADR-0077 §4.3, §6, §7 (ID-11 to ID-16): who removes a direction account. The team (admin, field) on any school; another
# direction of the same active school, there for at least 7 days, never itself. Another school's target is a 404.
module Policies
  module School
    class RemoveSchoolStaffPolicyTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 4, 9)
      DAY = 86_400
      SCHOOL_A = 7
      SCHOOL_B = 8

      # ADR-0092 : une direction a une fonction ; « head » par défaut, rang « gestion ».
      def actor(role, user_id: 1, school_id: nil, team_role: nil, staff_position: ("head" if role == :school_admin))
        Entities::Identity::Actor.new(user_id:, role:, team_role:, school_id:, staff_position:)
      end
      def school(id: SCHOOL_A, status: "active") = Entities::School::School.new(id:, status:)

      def staff(user_id:, school_id: SCHOOL_A, days: 10, archived_at: nil)
        Entities::School::Staff.new(user_id:, user_public_id: "u#{user_id}", school_id:, joined_via: "code", joined_at: NOW - (days * DAY),
                                    archived_at:, archived_by_id: archived_at && 99, position: "deputy")
      end

      setup do
        @policy = RemoveSchoolStaffPolicy.new
        @kofi = actor(:school_admin, user_id: 1, school_id: SCHOOL_A)
        @kofi_staff = staff(user_id: 1, days: 10)
        @aya = staff(user_id: 2, days: 2)
      end

      def call(actor: @kofi, school: self.school, target: @aya, actor_staff: @kofi_staff, now: NOW)
        @policy.call(actor:, school:, target:, actor_staff:, now:)
      end

      test "l'équipe admin ou field retire toute direction, de tout établissement, même inactif" do
        %w[admin field].each do |team_role|
          assert call(actor: actor(:team, team_role:), actor_staff: nil).success?, team_role
          assert call(actor: actor(:team, team_role:), actor_staff: nil, school: school(id: SCHOOL_B, status: "inactive"),
                      target: staff(user_id: 3, school_id: SCHOOL_B)).success?, team_role
        end
      end

      test "l'équipe content est refusée" do
        assert_equal :forbidden, call(actor: actor(:team, team_role: "content"), actor_staff: nil).code
      end

      test "ID-11, ID-12 : une direction arrivée depuis 7 jours ou plus retire une autre direction de son établissement" do
        assert call.success?
        assert call(actor_staff: staff(user_id: 1, days: 7)).success?, "7 jours tout juste"
      end

      test "ED-35: l'adjoint (ou directeur des études) retire aussi une direction" do
        assert call(actor: actor(:school_admin, user_id: 1, school_id: SCHOOL_A, staff_position: "deputy")).success?
      end

      # ED-32 : une secrétaire arrivée depuis 30 jours ne retire pas le chef d'établissement.
      test "ED-32: l'éducateur et la secrétaire sont refusés, même anciens, même contre le chef" do
        head = staff(user_id: 2, days: 40).with(position: "head")
        %w[educator secretary].each do |staff_position|
          assert_equal :forbidden, call(actor: actor(:school_admin, user_id: 1, school_id: SCHOOL_A, staff_position:),
                                        actor_staff: staff(user_id: 1, days: 30), target: head).code, staff_position
        end
      end

      test "ID-13 : un nouvel arrivant (moins de 7 jours) est refusé" do
        assert_equal :forbidden, call(actor_staff: staff(user_id: 1, days: 2)).code
        assert_equal :forbidden, call(actor_staff: staff(user_id: 1, days: 7).with(joined_at: NOW - (7 * DAY) + 1)).code
      end

      test "ID-14 : soi-même est refusé" do
        assert_equal :forbidden, call(target: @kofi_staff).code
      end

      test "ID-15 : une cible d'un autre établissement est introuvable" do
        assert_equal :not_found, call(target: staff(user_id: 3, school_id: SCHOOL_B), school: school(id: SCHOOL_B)).code
      end

      test "ID-16 : un établissement inactif ou en brouillon est refusé" do
        %w[inactive draft].each do |status|
          assert_equal :forbidden, call(school: school(status:)).code, status
        end
        assert_equal :forbidden, call(school: nil).code, "établissement introuvable"
      end

      test "un auteur archivé ou sans rattachement est refusé" do
        assert_equal :forbidden, call(actor_staff: staff(user_id: 1, archived_at: NOW - DAY)).code
        assert_equal :forbidden, call(actor_staff: nil).code
      end

      test "le visiteur, l'élève et l'enseignant sont refusés" do
        assert_equal :forbidden, call(actor: nil, actor_staff: nil).code
        assert_equal :forbidden, call(actor: actor(:student), actor_staff: nil).code
        assert_equal :forbidden, call(actor: actor(:teacher, school_id: SCHOOL_A), actor_staff: nil).code
      end
    end
  end
end

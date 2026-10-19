require "test_helper"

# ADR-0071 §4.1 : retirer et réintégrer un enseignant : la direction de cet établissement actif, jamais l'équipe (grill 9).
module Policies
  module School
    class ManageSchoolTeachersPolicyTest < ActiveSupport::TestCase
      # ADR-0092 : une direction a une fonction ; « head » par défaut, rang « gestion ».
      def actor(role, school_id: nil, team_role: nil, staff_position: ("head" if role == :school_admin))
        Entities::Identity::Actor.new(user_id: 1, role:, team_role:, school_id:, staff_position:)
      end
      def school(id: 7, status: "active") = Entities::School::School.new(id:, status:)

      setup { @policy = ManageSchoolTeachersPolicy.new }

      test "autorise la direction sur son établissement actif" do
        assert @policy.call(actor: actor(:school_admin, school_id: 7), school:).success?
      end

      test "ED-35: autorise le chef d'établissement et l'adjoint (ou directeur des études)" do
        %w[head deputy].each do |staff_position|
          assert @policy.call(actor: actor(:school_admin, school_id: 7, staff_position:), school:).success?, staff_position
        end
      end

      # ED-31 : retrait et réintégration passent tous deux par cette policy.
      test "ED-31: refuse l'éducateur et la secrétaire sur leur établissement actif, et une direction sans fonction" do
        [ "educator", "secretary", nil ].each do |staff_position|
          assert_equal :forbidden, @policy.call(actor: actor(:school_admin, school_id: 7, staff_position:), school:).code,
                       staff_position.inspect
        end
      end

      test "refuse la direction de A sur B" do
        assert_equal :forbidden, @policy.call(actor: actor(:school_admin, school_id: 8), school:).code
      end

      test "refuse la direction sur son établissement inactif ou en brouillon" do
        %w[inactive draft].each do |status|
          assert_equal :forbidden, @policy.call(actor: actor(:school_admin, school_id: 7), school: school(status:)).code, status
        end
      end

      test "refuse l'équipe, quel que soit son sous-rôle" do
        %w[admin content field].each do |team_role|
          assert_equal :forbidden, @policy.call(actor: actor(:team, team_role:), school:).code, team_role
        end
      end

      test "refuse l'élève, l'enseignant, la direction sans établissement, l'anonyme et l'établissement absent" do
        assert_equal :forbidden, @policy.call(actor: actor(:student), school:).code
        assert_equal :forbidden, @policy.call(actor: actor(:teacher, school_id: 7), school:).code
        assert_equal :forbidden, @policy.call(actor: actor(:school_admin), school:).code
        assert_equal :forbidden, @policy.call(actor: nil, school:).code
        assert_equal :forbidden, @policy.call(actor: actor(:school_admin, school_id: 7), school: nil).code
      end
    end
  end
end

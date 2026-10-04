require "test_helper"

# ADR-0077 §4.3 : la suppression des comptes direction archivés n'est lancée que par le système (la tâche planifiée).
module Policies
  module School
    class PurgeArchivedStaffPolicyTest < ActiveSupport::TestCase
      def actor(role, school_id: nil, team_role: nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:, school_id:)

      test "autorise le système, sans acteur" do
        assert PurgeArchivedStaffPolicy.new.call(actor: nil).success?
      end

      test "refuse toute personne connectée, l'équipe admin comprise" do
        policy = PurgeArchivedStaffPolicy.new

        [ actor(:team, team_role: "admin"), actor(:team, team_role: "field"), actor(:school_admin, school_id: 7),
          actor(:teacher, school_id: 7), actor(:student) ].each do |someone|
          assert_equal :forbidden, policy.call(actor: someone).code, someone.role
        end
      end
    end
  end
end

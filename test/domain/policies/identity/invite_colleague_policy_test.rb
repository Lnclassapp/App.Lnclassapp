require "test_helper"

module Policies
  module Identity
    # CP-07 (ADR-0063): only a teacher whose primary school is active invites a colleague.
    class InviteColleaguePolicyTest < ActiveSupport::TestCase
      def school(status: "active", id: 31) = Entities::School::School.new(id:, status:)
      def teacher(school_id: 31) = Entities::Identity::Actor.new(user_id: 7, role: :teacher, school_id:)

      test "autorise l'enseignant de son établissement principal actif" do
        assert InviteColleaguePolicy.new.call(actor: teacher, school: school).success?
      end

      test "refuse un établissement en brouillon ou désactivé, un enseignant sans école ou d'une autre école" do
        [ [ teacher, school(status: "draft") ], [ teacher, school(status: "inactive") ], [ teacher(school_id: nil), nil ],
          [ teacher, school(id: 32) ], [ teacher, nil ] ].each do |actor, fact|
          assert_equal :forbidden, InviteColleaguePolicy.new.call(actor:, school: fact).code
        end
      end

      test "refuse élève, direction, équipe et anonyme" do
        %i[student school_admin team].each do |role|
          actor = Entities::Identity::Actor.new(user_id: 7, role:, team_role: ("admin" if role == :team), school_id: 31)
          assert_equal :forbidden, InviteColleaguePolicy.new.call(actor:, school: school).code
        end
        assert_equal :forbidden, InviteColleaguePolicy.new.call(actor: nil, school: nil).code
      end
    end
  end
end

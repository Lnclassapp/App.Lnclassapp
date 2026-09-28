require "test_helper"

module Policies
  module School
    # CP-13 (ADR-0063): a sponsor is an active teacher of the same, active, school — never the requester.
    class VouchPolicyTest < ActiveSupport::TestCase
      def request = Entities::School::JoinRequest.new(id: 5, public_id: "req-5", teacher_id: 41, school_id: 31, status: "pending",
                                                      teacher_name: "Awa")
      def school(status: "active") = Entities::School::School.new(id: 31, status:)
      def teacher(user_id: 7, school_id: 31) = Entities::Identity::Actor.new(user_id:, role: :teacher, school_id:)

      test "autorise un enseignant actif du même établissement actif" do
        assert VouchPolicy.new.call(actor: teacher, request:, school:).success?
      end

      test "refuse un autre établissement, un établissement non actif, le demandeur lui-même" do
        [ [ teacher(school_id: 32), school ], [ teacher, school(status: "inactive") ], [ teacher(user_id: 41, school_id: 31), school ],
          [ teacher(school_id: nil), school ] ].each do |actor, fact|
          assert_equal :forbidden, VouchPolicy.new.call(actor:, request:, school: fact).code
        end
      end

      test "refuse l'équipe, un élève et un anonyme : l'équipe valide depuis la fiche" do
        [ Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin", school_id: 31),
          Entities::Identity::Actor.new(user_id: 7, role: :student, school_id: 31), nil ].each do |actor|
          assert_equal :forbidden, VouchPolicy.new.call(actor:, request:, school:).code
        end
      end
    end
  end
end

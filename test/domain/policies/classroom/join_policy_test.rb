require "test_helper"

module Policies
  module Classroom
    class JoinPolicyTest < ActiveSupport::TestCase
      def classroom(**overrides)
        Entities::Classroom::Classroom.new(name: "3ème 1", join_code: "abc23", active_students_count: 10, **overrides)
      end

      def call(actor: nil, code: "ABC 23", **overrides)
        JoinPolicy.new.call(actor:, classroom: classroom(**overrides), code:)
      end

      test "un visiteur ou un élève rejoint une classe active avec le code courant" do
        assert call.success?
        assert call(actor: Entities::Identity::Actor.new(user_id: 1, role: :student)).success?
      end

      test "un enseignant, la direction ou l'équipe sont refusés" do
        %i[teacher school_admin team].each do |role|
          result = call(actor: Entities::Identity::Actor.new(user_id: 1, role:))

          assert_equal :forbidden, result.code
          assert_empty result.errors
        end
      end

      test "chaque refus nomme sa raison" do
        assert_equal [ :classroom_archived ], call(status: "archived").errors[:base]
        assert_equal [ :join_code_revoked ], call(code: "xyz23").errors[:base]
        assert_equal [ :join_code_revoked ], call(join_code: nil, code: "").errors[:base]
        assert_equal [ :classroom_full ], call(active_students_count: 80).errors[:base]
      end
    end
  end
end

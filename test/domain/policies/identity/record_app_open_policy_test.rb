require "test_helper"

module Policies
  module Identity
    # ADR-0028, ADR-0082 §4.3-§4.4: only a student or a teacher has an opening from the installed app recorded, the two
    # roles the pilotage counts (data minimisation).
    class RecordAppOpenPolicyTest < ActiveSupport::TestCase
      def actor(role) = Entities::Identity::Actor.new(user_id: 7, role:, team_role: ("admin" if role == :team), school_id: 31)

      test "autorise l'élève" do
        assert RecordAppOpenPolicy.new.call(actor: actor(:student)).success?
      end

      test "autorise l'enseignant" do
        assert RecordAppOpenPolicy.new.call(actor: actor(:teacher)).success?
      end

      test "refuse l'anonyme" do
        assert_equal :forbidden, RecordAppOpenPolicy.new.call(actor: nil).code
      end

      test "refuse la direction" do
        assert_equal :forbidden, RecordAppOpenPolicy.new.call(actor: actor(:school_admin)).code
      end

      test "refuse l'équipe" do
        assert_equal :forbidden, RecordAppOpenPolicy.new.call(actor: actor(:team)).code
      end
    end
  end
end

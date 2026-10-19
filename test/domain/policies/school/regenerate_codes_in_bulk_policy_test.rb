require "test_helper"

# ADR-0096 §4.1, RM-09, RM-22: only an admin member of the team launches a mass regeneration, of codes or of links.
module Policies
  module School
    class RegenerateCodesInBulkPolicyTest < ActiveSupport::TestCase
      def call(actor) = RegenerateCodesInBulkPolicy.new.call(actor:)
      def actor(role, team_role: nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:, school_id: (5 unless role == :team))

      test "an admin of the team may launch it" do
        assert call(actor(:team, team_role: "admin")).success?
      end

      test "the other members of the team may not" do
        %w[content field].each { |team_role| assert_equal :forbidden, call(actor(:team, team_role:)).code, team_role }
        assert_equal :forbidden, call(actor(:team)).code
      end

      test "a direction, a teacher, a student and a visitor may not" do
        %i[school_admin teacher student].each { |role| assert_equal :forbidden, call(actor(role)).code, role }
        assert_equal :forbidden, call(nil).code
      end
    end
  end
end

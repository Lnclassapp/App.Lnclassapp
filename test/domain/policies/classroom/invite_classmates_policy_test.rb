require "test_helper"

module Policies
  module Classroom
    class InviteClassmatesPolicyTest < ActiveSupport::TestCase
      def call(actor) = InviteClassmatesPolicy.new.call(actor:)
      def actor(role) = Entities::Identity::Actor.new(user_id: 1, role:, school_id: nil)

      test "un élève invite ses camarades" do
        assert call(actor(:student)).success?
      end

      test "l'enseignant, la direction, l'équipe et l'anonyme sont refusés" do
        %i[teacher school_admin team].each { |role| assert_equal :forbidden, call(actor(role)).code, role }
        assert_equal :forbidden, call(nil).code
      end
    end
  end
end

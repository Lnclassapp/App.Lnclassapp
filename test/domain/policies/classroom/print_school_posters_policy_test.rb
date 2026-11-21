require "test_helper"

module Policies
  module Classroom
    class PrintSchoolPostersPolicyTest < ActiveSupport::TestCase
      SCHOOL = Struct.new(:id)

      def call(actor, school_id: 7) = PrintSchoolPostersPolicy.new.call(actor:, school: SCHOOL.new(school_id))
      def actor(role, user_id: 1, school_id: nil) = Entities::Identity::Actor.new(user_id:, role:, school_id:)

      test "l'équipe imprime le kit de tout établissement" do
        assert call(actor(:team, user_id: 9)).success?
      end

      test "la direction imprime le kit de son établissement" do
        assert call(actor(:school_admin, school_id: 7)).success?
      end

      test "l'établissement d'une autre direction, ou d'un enseignant, n'existe pas" do
        assert_equal :not_found, call(actor(:school_admin, school_id: 8)).code
        assert_equal :not_found, call(actor(:school_admin)).code
        assert_equal :not_found, call(actor(:teacher, school_id: 7)).code
      end

      test "refuse un élève et l'anonyme" do
        assert_equal :forbidden, call(actor(:student)).code
        assert_equal :forbidden, call(nil).code
      end
    end
  end
end

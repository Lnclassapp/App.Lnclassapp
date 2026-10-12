require "test_helper"

module Policies
  module Classroom
    class ManageClassroomMembersPolicyTest < ActiveSupport::TestCase
      SCHOOL_ID = 7

      def classroom = Entities::Classroom::Classroom.new(school_id: SCHOOL_ID, teacher_ids: [ 1 ])
      def call(actor) = ManageClassroomMembersPolicy.new.call(actor:, classroom:)
      def actor(role, user_id: 1, school_id: nil) = Entities::Identity::Actor.new(user_id:, role:, school_id:)

      test "IL-12: l'enseignant de la classe, la direction de son établissement et l'équipe" do
        assert call(actor(:teacher)).success?
        assert call(actor(:school_admin, user_id: 5, school_id: SCHOOL_ID)).success?
        assert call(actor(:team, user_id: 9)).success?
      end

      test "IL-12: la classe n'existe pas pour un enseignant qui n'y enseigne pas" do
        assert_equal :not_found, call(actor(:teacher, user_id: 2)).code
      end

      test "IL-12: la classe n'existe pas pour la direction d'un autre établissement, ni pour une direction sans établissement" do
        assert_equal :not_found, call(actor(:school_admin, school_id: SCHOOL_ID + 1)).code
        assert_equal :not_found, call(actor(:school_admin)).code
      end

      test "IL-12: refuse un élève et l'anonyme" do
        assert_equal :forbidden, call(actor(:student)).code
        assert_equal :forbidden, call(nil).code
      end
    end
  end
end

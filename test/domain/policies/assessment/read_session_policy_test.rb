require "test_helper"

module Policies
  module Assessment
    class ReadSessionPolicyTest < ActiveSupport::TestCase
      Session = Data.define(:student_id)

      def call(role, user_id = 1, teaches_student: false)
        ReadSessionPolicy.new.call(actor: Entities::Identity::Actor.new(user_id:, role:), session: Session.new(1), teaches_student:)
      end

      test "l'élève propriétaire, l'enseignant de l'élève et l'équipe" do
        assert call(:student).success?
        assert call(:teacher, 5, teaches_student: true).success?
        assert call(:team, 9).success?
      end

      test "refuse un autre élève, un enseignant étranger, la direction et l'anonyme" do
        assert_equal :forbidden, call(:student, 2).code
        assert_equal :forbidden, call(:teacher, 5).code
        assert_equal :forbidden, call(:school_admin, 1).code
        assert_equal :forbidden, ReadSessionPolicy.new.call(actor: nil, session: Session.new(1)).code
      end
    end
  end
end

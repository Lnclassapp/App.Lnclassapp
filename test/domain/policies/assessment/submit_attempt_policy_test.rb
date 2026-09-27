require "test_helper"

module Policies
  module Assessment
    class SubmitAttemptPolicyTest < ActiveSupport::TestCase
      Session = Data.define(:student_id, :status) do
        def started? = status == "started"
      end

      def call(user_id: 1, role: :student, status: "started")
        SubmitAttemptPolicy.new.call(actor: Entities::Identity::Actor.new(user_id:, role:), session: Session.new(1, status))
      end

      test "l'élève propriétaire répond dans une session ouverte" do
        assert call.success?
      end

      test "une session close refuse, avec sa raison" do
        assert_equal [ :session_closed ], call(status: "completed").errors[:base]
      end

      test "refuse un autre élève, un autre rôle et l'anonyme" do
        assert_equal :forbidden, call(user_id: 2).code
        assert_equal :forbidden, call(role: :team).code
        assert_equal :forbidden, SubmitAttemptPolicy.new.call(actor: nil, session: Session.new(1, "started")).code
      end
    end
  end
end

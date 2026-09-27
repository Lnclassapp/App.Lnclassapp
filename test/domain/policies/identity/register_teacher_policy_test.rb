require "test_helper"

module Policies
  module Identity
    class RegisterTeacherPolicyTest < ActiveSupport::TestCase
      test "autorise le visiteur anonyme" do
        assert RegisterTeacherPolicy.new.call(actor: nil).success?
      end

      test "refuse tout acteur connecté" do
        %i[student teacher school_admin team].each do |role|
          result = RegisterTeacherPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role:))

          assert_equal :forbidden, result.code
          assert_equal [ :already_signed_in ], result.errors[:base]
        end
      end
    end
  end
end

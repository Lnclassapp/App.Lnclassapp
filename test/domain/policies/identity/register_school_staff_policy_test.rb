require "test_helper"

# ADR-0077 §4.3: only a visitor who is not signed in registers as a direction with the school code.
module Policies
  module Identity
    class RegisterSchoolStaffPolicyTest < ActiveSupport::TestCase
      test "autorise le visiteur anonyme" do
        assert RegisterSchoolStaffPolicy.new.call(actor: nil).success?
      end

      test "refuse tout acteur connecté" do
        %i[student teacher school_admin team].each do |role|
          result = RegisterSchoolStaffPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role:))

          assert_equal :forbidden, result.code, role
          assert_equal [ :already_signed_in ], result.errors[:base], role
        end
      end
    end
  end
end

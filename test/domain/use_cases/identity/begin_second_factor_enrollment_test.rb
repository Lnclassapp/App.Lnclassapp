require "test_helper"

module UseCases
  module Identity
    class BeginSecondFactorEnrollmentTest < ActiveSupport::TestCase
      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def initialize(user) = @user = user
        def find(id:) = (@user if @user&.id == id)
      end

      class FakeSecondFactors
        include Ports::Identity::SecondFactorRepositoryPort

        attr_reader :label

        def initialize(state) = @state = state
        def state_for(user_id:) = @state

        def begin_enrollment(user_id:, label:)
          @label = label
          Enrollment.new(secret: "SECRET", provisioning_uri: "otpauth://totp/x")
        end
      end

      def team_user = Entities::Identity::User.new(id: 1, role: "team", team_role: "admin", contact: "0701020304")

      def begin_enrollment(user: team_user, state: nil)
        @second_factors = FakeSecondFactors.new(state)
        BeginSecondFactorEnrollment.new(users: FakeUsers.new(user), second_factors: @second_factors).call(user_id: 1)
      end

      test "renvoie le secret et l'URI d'un compte team non confirmé" do
        result = begin_enrollment

        assert_equal "SECRET", result.value.secret
        assert_equal "0701020304", @second_factors.label
      end

      test "recommence une activation non confirmée" do
        assert begin_enrollment(state: Ports::Identity::SecondFactorRepositoryPort::State.new(confirmed: false, backup_codes_left: 0)).success?
      end

      test "refuse un compte confirmé, un compte hors équipe et un compte absent" do
        confirmed = Ports::Identity::SecondFactorRepositoryPort::State.new(confirmed: true, backup_codes_left: 10)

        assert_equal [ :already_enrolled ], begin_enrollment(state: confirmed).errors[:base]
        assert_equal [ :not_team ], begin_enrollment(user: Entities::Identity::User.new(id: 1, role: "teacher")).errors[:base]
        assert_equal :not_found, begin_enrollment(user: nil).code
        assert_nil @second_factors.label
      end
    end
  end
end

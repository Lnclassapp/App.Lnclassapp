require "test_helper"

module UseCases
  module Identity
    class BeginSecondFactorEnrollmentTest < ActiveSupport::TestCase
      Enrollment = Ports::Identity::SecondFactorRepositoryPort::Enrollment

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def find(id:) = Entities::Identity::User.new(id:, role: "team", team_role: "admin", contact: "0701020304")
      end

      class FakeSecondFactors
        include Ports::Identity::SecondFactorRepositoryPort

        attr_reader :begun

        def begin_enrollment(user_id:, label:)
          @begun = [ user_id, label ]
          Enrollment.new(secret: "SECRET", provisioning_uri: "otpauth://totp/Lnclass:#{label}")
        end
      end

      def session(role: "team", confirmed: false)
        Entities::Identity::SessionState.new(id: 5, user_id: 9, role:, created_at: nil, last_seen_at: nil,
                                             second_factor_verified_at: nil, second_factor_confirmed: confirmed)
      end

      def begin_enrollment(session)
        @second_factors = FakeSecondFactors.new
        BeginSecondFactorEnrollment.new(users: FakeUsers.new, second_factors: @second_factors,
                                        policy: Policies::Identity::SecondFactorPolicy.new).call(session:)
      end

      test "returns the secret and the provisioning URI labelled with the contact" do
        result = begin_enrollment(session)

        assert_equal Enrollment.new(secret: "SECRET", provisioning_uri: "otpauth://totp/Lnclass:0701020304"), result.value
        assert_equal [ 9, "0701020304" ], @second_factors.begun
      end

      test "a confirmed factor or a non team account is refused" do
        assert_equal({ base: [ :already_enrolled ] }, begin_enrollment(session(confirmed: true)).errors)
        assert_equal :forbidden, begin_enrollment(session(role: "teacher")).code
        assert_nil @second_factors.begun
      end
    end
  end
end

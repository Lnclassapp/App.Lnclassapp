require "test_helper"

module UseCases
  module Identity
    # F-07, ADR-0031: a team member resets the second factor of another member; the member is signed out everywhere and
    # must enrol again; "totp.reset" is audited; nobody resets their own second factor.
    class ResetSecondFactorTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 26, 10)
      Clock = Data.define(:now)
      ACTOR = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field")
      MEMBER = Entities::Identity::User.new(id: 8, public_id: "team8", role: "team", team_role: "content", contact: "0700000008")
      SELF = Entities::Identity::User.new(id: 7, public_id: "team7", role: "team", team_role: "field")
      TEACHER = Entities::Identity::User.new(id: 9, public_id: "tea9", role: "teacher")

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def find_by_public_id(public_id:) = [ MEMBER, SELF, TEACHER ].find { it.public_id == public_id }
      end

      class FakeSecondFactors
        include Ports::Identity::SecondFactorRepositoryPort

        attr_reader :resets

        def reset(user_id:) = (@resets ||= []) << user_id
      end

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :destroyed_for

        def destroy_all_for(user_id:) = (@destroyed_for ||= []) << user_id
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def record(**event) = (@events ||= []) << event
      end

      def reset(actor: ACTOR, target: MEMBER.public_id)
        @second_factors = FakeSecondFactors.new
        @sessions = FakeSessions.new
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        ResetSecondFactor.new(users: FakeUsers.new, second_factors: @second_factors, sessions: @sessions, audit_log: @audit,
                              transaction: @transaction, policy: Policies::Identity::ResetSecondFactorPolicy.new,
                              clock: Clock.new(NOW))
                         .call(actor:, target_public_id: target)
      end

      test "the second factor and every session of the member are removed in one transaction, and audited" do
        result = reset

        assert result.success?
        assert_equal MEMBER, result.value
        assert_equal [ 8 ], @second_factors.resets
        assert_equal [ 8 ], @sessions.destroyed_for
        assert_equal [ { action: "totp.reset", actor_id: 7, at: NOW, subject_type: "User", subject_id: 8 } ], @audit.events
        assert_equal 1, @transaction.calls
      end

      test "one's own second factor, a non-team account, another role and the visitor are refused, without writing" do
        [ [ ACTOR, SELF ], [ ACTOR, TEACHER ], [ Entities::Identity::Actor.new(user_id: 3, role: :teacher), MEMBER ],
          [ nil, MEMBER ] ].each do |actor, target|
          result = reset(actor:, target: target.public_id)

          assert_equal :forbidden, result.code
          assert_nil @second_factors.resets
          assert_nil @sessions.destroyed_for
          assert_nil @audit.events
          assert_equal 0, @transaction.calls
        end
      end

      test "an unknown account is not found" do
        assert_equal :not_found, reset(target: "inconnu").code
        assert_nil @second_factors.resets
      end
    end
  end
end

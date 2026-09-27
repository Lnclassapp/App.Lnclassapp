require "test_helper"

module Repositories
  module Identity
    class SessionRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = SessionRepository.new
        @at = Time.current.change(usec: 0)
      end

      def create_for(user, digest: "d" * 64)
        @repository.create(user_id: user.id, token_digest: digest, ip: "10.0.0.1", user_agent: "Chrome", at: @at)
      end

      test "create stores the digest and the client, then finds the session by it" do
        student = create_student
        id = create_for(student)

        state = @repository.find_by_token_digest(token_digest: "d" * 64)

        assert_equal Entities::Identity::SessionState.new(id:, user_id: student.id, role: "student", created_at: @at, last_seen_at: @at,
                                                          second_factor_verified_at: nil, second_factor_confirmed: false), state
        assert_equal [ "10.0.0.1", "Chrome" ], Orm::Session.find(id).values_at(:ip_address, :user_agent)
      end

      test "an unknown digest is nil" do
        assert_nil @repository.find_by_token_digest(token_digest: "x" * 64)
      end

      test "a long user agent is truncated and a missing one is nil" do
        id = @repository.create(user_id: create_student.id, token_digest: "e" * 64, ip: nil, user_agent: "A" * 300, at: @at)

        assert_equal [ nil, 255 ], [ Orm::Session.find(id).ip_address, Orm::Session.find(id).user_agent.length ]
      end

      test "the session of a team member tells whether the second factor is confirmed" do
        confirmed = create_team_member
        pending = create_team_member(second_factor: false)
        Orm::TotpCredential.create!(user: pending, secret: ROTP::Base32.random)

        create_for(confirmed, digest: "a" * 64)
        create_for(pending, digest: "b" * 64)

        assert @repository.find_by_token_digest(token_digest: "a" * 64).second_factor_confirmed
        assert_not @repository.find_by_token_digest(token_digest: "b" * 64).second_factor_confirmed
      end

      test "touch and mark_second_factor_verified update the session" do
        id = create_for(create_team_member)
        later = @at + 10.minutes

        assert @repository.touch(id:, at: later)
        assert_equal later, @repository.find_by_token_digest(token_digest: "d" * 64).last_seen_at

        assert @repository.mark_second_factor_verified(id:, at: later + 1.minute)
        state = @repository.find_by_token_digest(token_digest: "d" * 64)
        assert state.verified?
        assert_equal later + 1.minute, state.last_seen_at
      end

      test "destroy is idempotent and destroy_all_for counts the sessions of the account" do
        student = create_student
        id = create_for(student)
        create_for(student, digest: "f" * 64)
        create_for(create_student, digest: "g" * 64)

        assert @repository.destroy(id:)
        assert @repository.destroy(id:)
        assert_equal 1, @repository.destroy_all_for(user_id: student.id)
        assert_equal 1, Orm::Session.count
      end

      test "destroy_all_except keeps the given session of the account, and only it" do
        student = create_student
        kept = create_for(student)
        create_for(student, digest: "f" * 64)
        create_for(student, digest: "e" * 64)
        other = create_for(create_student, digest: "g" * 64)

        assert_equal 2, @repository.destroy_all_except(user_id: student.id, keep_id: kept)
        assert_equal [ kept, other ].sort, Orm::Session.pluck(:id).sort
        assert_equal 0, @repository.destroy_all_except(user_id: student.id, keep_id: kept)
      end
    end
  end
end

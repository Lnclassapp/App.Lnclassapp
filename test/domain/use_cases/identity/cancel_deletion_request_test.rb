require "test_helper"

module UseCases
  module Identity
    # ADR-0036, amendment (2): the student or the parent takes the request back; the team `admin` (ADR-0038) cancels the
    # pending request, the account stays as it is, and the journal keeps who and when.
    class CancelDeletionRequestTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 2, 10)
      Clock = Data.define(:now)
      ADMIN = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")
      STUDENT = Entities::Identity::User.new(id: 8, public_id: "stu8", role: "student", first_name: "Awa", last_name: "Koné",
                                             contact: "0100000008", gender: "female")
      TEACHER = Entities::Identity::User.new(id: 10, public_id: "tea10", role: "teacher", first_name: "Yao", last_name: "Brou",
                                             contact: "0500000010", gender: "male")
      PENDING = Entities::Identity::DeletionRequest.new(id: 3, user_id: 8, requested_on: Date.new(2026, 9, 20), status: "pending")

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def find_by_public_id(public_id:) = [ STUDENT, TEACHER ].find { it.public_id == public_id }
      end

      class FakeDeletionRequests
        include Ports::Identity::DeletionRequestRepositoryPort

        attr_reader :closed

        # race: the request was closed by someone else between the check and the write.
        def initialize(pending:, race: false)
          @pending = pending
          @race = race
          @closed = []
        end

        def pending_for(user_id:) = @pending
        def close(user_id:, status:, closed_by_id:, at:)
          return if @race

          @closed << { user_id:, status:, closed_by_id:, at: }
          @pending.with(status:)
        end
      end

      def cancel(actor: ADMIN, target: STUDENT.public_id, pending: PENDING, race: false)
        @requests = FakeDeletionRequests.new(pending:, race:)
        @audit = FakeAuditLog.new
        @transaction = FakeTransaction.new
        CancelDeletionRequest.new(users: FakeUsers.new, deletion_requests: @requests, audit_log: @audit, transaction: @transaction,
                                  policy: Policies::Identity::DeleteUserPolicy.new, clock: Clock.new(NOW))
                             .call(actor:, target_public_id: target)
      end

      def assert_nothing_written
        assert_empty @requests.closed
        assert_empty @audit.events
      end

      test "the pending request is cancelled by the team member, in the journal with its date of reception" do
        result = cancel

        assert result.success?
        assert_equal PENDING.with(status: "cancelled"), result.value
        assert_equal [ { user_id: 8, status: "cancelled", closed_by_id: 7, at: NOW } ], @requests.closed
        assert_equal [ { action: "user.deletion_request_cancelled", actor_id: 7, at: NOW, subject_type: "User", subject_id: 8,
                         metadata: { requested_on: "2026-09-20" } } ], @audit.events
        assert_equal 1, @transaction.calls
      end

      test "a team member content or field, and every other role, are refused without writing" do
        [ Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content"),
          Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field"),
          Entities::Identity::Actor.new(user_id: 8, role: :student), Entities::Identity::Actor.new(user_id: 10, role: :teacher),
          Entities::Identity::Actor.new(user_id: 12, role: :school_admin, school_id: 3), nil ].each do |actor|
          assert_equal :forbidden, cancel(actor:).code
          assert_nothing_written
          assert_equal 0, @transaction.calls
        end
      end

      test "an unknown account, a teacher, or an account without pending request has nothing to cancel" do
        assert_equal :not_found, cancel(target: "inconnu").code
        assert_nothing_written
        assert_equal :forbidden, cancel(target: TEACHER.public_id).code
        assert_nothing_written
        assert_equal :not_found, cancel(pending: nil).code
        assert_nothing_written
        assert_equal 0, @transaction.calls
      end

      test "a request closed concurrently is not cancelled twice, nor written to the journal" do
        assert_equal :not_found, cancel(race: true).code
        assert_nothing_written
      end
    end
  end
end

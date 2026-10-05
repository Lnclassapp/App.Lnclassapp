require "test_helper"

module UseCases
  module Identity
    # ADR-0036, amendment (2): the team `admin` (ADR-0038) records a deletion request when the support receives it, with
    # its date, never in the future; one pending request per student account; the journal keeps who and when.
    class RecordDeletionRequestTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 2, 10)
      Clock = Data.define(:now)
      ADMIN = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")
      STUDENT = Entities::Identity::User.new(id: 8, public_id: "stu8", role: "student", first_name: "Awa", last_name: "Koné",
                                             contact: "0100000008", gender: "female")
      GONE = Entities::Identity::User.new(id: 9, public_id: "stu9", role: "student", first_name: "Compte", last_name: "supprimé",
                                          gender: "male", anonymized_at: NOW - 86_400)
      TEACHER = Entities::Identity::User.new(id: 10, public_id: "tea10", role: "teacher", first_name: "Yao", last_name: "Brou",
                                             contact: "0500000010", gender: "male")

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def find_by_public_id(public_id:) = [ STUDENT, GONE, TEACHER ].find { it.public_id == public_id }
      end

      class FakeDeletionRequests
        include Ports::Identity::DeletionRequestRepositoryPort

        attr_reader :recorded

        def initialize(pending: nil, race: false)
          @pending = pending
          @race = race
          @recorded = []
        end

        def pending_for(user_id:) = @pending&.then { it.user_id == user_id ? it : nil }

        # race: another member recorded the same request between the check and the write.
        def record(user_id:, requested_on:, recorded_by_id:, at:)
          return Shared::Result.failure(:conflict, errors: { base: [ :already_pending ] }) if @race

          @recorded << { user_id:, requested_on:, recorded_by_id:, at: }
          Shared::Result.success(Entities::Identity::DeletionRequest.new(id: 1, user_id:, requested_on:, status: "pending"))
        end
      end

      def record_request(actor: ADMIN, target: STUDENT.public_id, requested_on: "2026-09-20", pending: nil, race: false)
        @requests = FakeDeletionRequests.new(pending:, race:)
        @audit = FakeAuditLog.new
        @transaction = FakeTransaction.new
        RecordDeletionRequest.new(users: FakeUsers.new, deletion_requests: @requests, audit_log: @audit, transaction: @transaction,
                                  policy: Policies::Identity::DeleteUserPolicy.new, clock: Clock.new(NOW))
                             .call(actor:, target_public_id: target, dto: Dtos::Identity::DeletionRequestInput.new(requested_on:))
      end

      def assert_nothing_written
        assert_empty @requests.recorded
        assert_empty @audit.events
        assert_equal 0, @transaction.calls
      end

      test "the request is recorded with its date of reception and the team member, in one transaction, in the journal" do
        result = record_request

        assert result.success?
        assert_equal Entities::Identity::DeletionRequest.new(id: 1, user_id: 8, requested_on: Date.new(2026, 9, 20), status: "pending"),
                     result.value
        assert_equal [ { user_id: 8, requested_on: Date.new(2026, 9, 20), recorded_by_id: 7, at: NOW } ], @requests.recorded
        assert_equal [ { action: "user.deletion_requested", actor_id: 7, at: NOW, subject_type: "User", subject_id: 8,
                         metadata: { requested_on: "2026-09-20" } } ], @audit.events
        assert_equal 1, @transaction.calls
      end

      test "a request received today is recorded" do
        assert record_request(requested_on: "2026-10-02").success?
      end

      test "a team member content or field, and every other role, are refused without writing" do
        [ Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content"),
          Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field"),
          Entities::Identity::Actor.new(user_id: 8, role: :student), Entities::Identity::Actor.new(user_id: 10, role: :teacher),
          Entities::Identity::Actor.new(user_id: 12, role: :school_admin, school_id: 3), nil ].each do |actor|
          assert_equal :forbidden, record_request(actor:).code
          assert_nothing_written
        end
      end

      test "only a student account takes a deletion request; an unknown account is not found" do
        assert_equal :forbidden, record_request(target: TEACHER.public_id).code
        assert_nothing_written
        assert_equal :not_found, record_request(target: "inconnu").code
        assert_nothing_written
      end

      test "an account already deleted is a conflict" do
        result = record_request(target: GONE.public_id)

        assert_equal [ :conflict, { base: [ :already_anonymized ] } ], [ result.code, result.errors ]
        assert_nothing_written
      end

      test "the date of reception is required, and never in the future" do
        [ [ "", :blank ], [ "pas une date", :blank ], [ "2026-10-03", :in_future ] ].each do |requested_on, error|
          result = record_request(requested_on:)

          assert_equal :invalid, result.code
          assert_includes result.errors[:requested_on], error
          assert_nothing_written
        end
      end

      test "one pending request per account: a second one is a conflict, even recorded concurrently" do
        pending = Entities::Identity::DeletionRequest.new(id: 3, user_id: 8, requested_on: Date.new(2026, 9, 1), status: "pending")

        result = record_request(pending:)
        assert_equal [ :conflict, { base: [ :already_pending ] } ], [ result.code, result.errors ]
        assert_nothing_written

        result = record_request(race: true)
        assert_equal [ :conflict, { base: [ :already_pending ] } ], [ result.code, result.errors ]
        assert_empty @audit.events
      end

      test "the pending request of another account does not block" do
        other = Entities::Identity::DeletionRequest.new(id: 3, user_id: 99, requested_on: Date.new(2026, 9, 1), status: "pending")

        assert record_request(pending: other).success?
      end
    end
  end
end

require "test_helper"

module UseCases
  module Identity
    # ADR-0036 §4, lot R of fonctions-espace-eleve: a student or a parent asks the support to delete the account; the team
    # handles the request within 30 days by anonymizing it, in one transaction, with the date of the request in the journal.
    # ADR-0036, amendment (2), lot R2: its sessions, attempts, badges and gaps are erased in the same transaction; the account
    # itself stays, anonymized.
    class AnonymizeUserTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 2, 10)
      Clock = Data.define(:now)
      TEAM = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")
      STUDENT = Entities::Identity::User.new(id: 8, public_id: "stu8", role: "student", first_name: "Awa", last_name: "Koné",
                                             contact: "0100000008", gender: "female")
      GONE = Entities::Identity::User.new(id: 9, public_id: "stu9", role: "student", first_name: "Compte", last_name: "supprimé",
                                          gender: "male", anonymized_at: NOW - 86_400)
      TEACHER = Entities::Identity::User.new(id: 10, public_id: "tea10", role: "teacher", first_name: "Yao", last_name: "Brou",
                                             contact: "0500000010", gender: "male")
      MEMBER = Entities::Identity::User.new(id: 11, public_id: "team11", role: "team", team_role: "admin", first_name: "Ali",
                                            last_name: "Sow", contact: "0700000011", gender: "male")

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        attr_reader :anonymized

        def find_by_public_id(public_id:) = [ STUDENT, GONE, TEACHER, MEMBER ].find { it.public_id == public_id }
        def anonymize(user_id:, first_name:, last_name:, at:) = (@anonymized ||= []) << [ user_id, first_name, last_name, at ]
      end

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :destroyed_for

        def destroy_all_for(user_id:) = (@destroyed_for ||= []) << user_id
      end

      class FakeSecondFactors
        include Ports::Identity::SecondFactorRepositoryPort

        attr_reader :resets

        def reset(user_id:) = (@resets ||= []) << user_id
      end

      class FakePinRecoveries
        include Ports::Identity::PinRecoveryRepositoryPort

        attr_reader :destroyed_for

        def destroy_all_for(user_id:) = (@destroyed_for ||= []) << user_id
      end

      class FakeLoginAttempts
        include Ports::Identity::LoginAttemptRepositoryPort

        attr_reader :destroyed_for

        def destroy_all_for(user_id:, contact:) = (@destroyed_for ||= []) << [ user_id, contact ]
      end

      class FakeMemberships
        include Ports::Classroom::MembershipRepositoryPort

        attr_reader :left

        def leave_all(student_id:, at:) = (@left ||= []) << [ student_id, at ]
      end

      # Knows whether the transaction is open, to prove that the erasure and the closing happen inside it.
      class TrackingTransaction < FakeTransaction
        def open? = @open == true

        def call
          super do
            @open = true
            yield
          end
        ensure
          @open = false
        end
      end

      class FakeLearningData
        include Ports::Assessment::LearningDataEraserPort

        attr_reader :erased_for

        def initialize(transaction) = @transaction = transaction
        def erase_for(student_id:) = (@erased_for ||= []) << [ student_id, @transaction.open? ]
      end

      # ADR-0036, amendment (2): the pending request of the account, if any, is closed as processed, inside the transaction.
      class FakeDeletionRequests
        include Ports::Identity::DeletionRequestRepositoryPort

        attr_reader :closed

        def initialize(transaction:, pending: nil)
          @transaction = transaction
          @pending = pending
          @closed = []
        end

        def close(user_id:, status:, closed_by_id:, at:)
          @closed << { user_id:, status:, closed_by_id:, at:, in_transaction: @transaction.open? }
          @pending&.with(status:)
        end
      end

      def anonymize(actor: TEAM, target: STUDENT.public_id, requested_on: "2026-09-20", pending: nil)
        @users = FakeUsers.new
        @sessions = FakeSessions.new
        @second_factors = FakeSecondFactors.new
        @pin_recoveries = FakePinRecoveries.new
        @login_attempts = FakeLoginAttempts.new
        @memberships = FakeMemberships.new
        @photos = FakeProfilePhotoStore.new(8 => Ports::Identity::ProfilePhotoStorePort::StoredPhoto.new(content_type: "image/png", data: "x"))
        @audit = FakeAuditLog.new
        @transaction = TrackingTransaction.new
        @learning_data = FakeLearningData.new(@transaction)
        @deletion_requests = FakeDeletionRequests.new(transaction: @transaction, pending:)
        AnonymizeUser.new(users: @users, sessions: @sessions, second_factors: @second_factors, pin_recoveries: @pin_recoveries,
                          login_attempts: @login_attempts, memberships: @memberships, photos: @photos, audit_log: @audit,
                          learning_data: @learning_data, transaction: @transaction,
                          policy: Policies::Identity::DeleteUserPolicy.new, clock: Clock.new(NOW), deletion_requests: @deletion_requests)
                     .call(actor:, target_public_id: target, dto: Dtos::Identity::DeletionRequestInput.new(requested_on:))
      end

      def assert_nothing_written
        assert_nil @users.anonymized
        assert_nil @sessions.destroyed_for
        assert_nil @login_attempts.destroyed_for
        assert_nil @memberships.left
        assert_nil @learning_data.erased_for
        assert_empty @photos.writes
        assert_empty @audit.events
        assert_empty @deletion_requests.closed
        assert_equal 0, @transaction.calls
      end

      test "the account is renamed « Compte supprimé », signed out, without codes, photo or open membership, in one transaction" do
        result = anonymize

        assert result.success?
        assert_equal STUDENT, result.value.user
        assert_equal Date.new(2026, 9, 20), result.value.requested_on
        assert_equal [ [ 8, "Compte", "supprimé", NOW ] ], @users.anonymized
        assert_equal [ 8 ], @sessions.destroyed_for
        assert_equal [ 8 ], @second_factors.resets
        assert_equal [ 8 ], @pin_recoveries.destroyed_for
        assert_equal [ [ 8, "0100000008" ] ], @login_attempts.destroyed_for
        assert_equal [ [ 8, NOW ] ], @memberships.left
        assert_equal [ [ :remove, 8 ] ], @photos.writes
        assert_equal 1, @transaction.calls
      end

      test "its sessions, attempts, badges and gaps are erased inside the transaction: it leaves every statistic" do
        assert anonymize.success?

        assert_equal [ [ 8, true ] ], @learning_data.erased_for
        assert_not @transaction.open?
      end

      test "the journal keeps the team member and the date of the request, never the erased data" do
        anonymize

        assert_equal [ { action: "user.anonymized", actor_id: 7, at: NOW, subject_type: "User", subject_id: 8,
                         metadata: { requested_on: "2026-09-20" } } ], @audit.events
        assert_no_match(/Awa|Koné|0100000008/, @audit.events.inspect)
      end

      test "the pending request of the account is processed, inside the transaction, by the team member" do
        pending = Entities::Identity::DeletionRequest.new(id: 3, user_id: 8, requested_on: Date.new(2026, 9, 20), status: "pending")

        assert anonymize(pending:).success?
        assert_equal [ { user_id: 8, status: "processed", closed_by_id: 7, at: NOW, in_transaction: true } ], @deletion_requests.closed
      end

      test "an account deleted without a recorded request is still deleted" do
        assert anonymize.success?
        assert_equal [ "processed" ], @deletion_requests.closed.pluck(:status)
        assert_equal 1, @audit.events.size
      end

      test "a request received today is handled" do
        assert anonymize(requested_on: "2026-10-02").success?
      end

      test "a student, a teacher, a school management and a visitor are refused, without writing" do
        [ Entities::Identity::Actor.new(user_id: 8, role: :student), Entities::Identity::Actor.new(user_id: 10, role: :teacher),
          Entities::Identity::Actor.new(user_id: 12, role: :school_admin, school_id: 3), nil,
          Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content"),
          Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field") ].each do |actor|
          assert_equal :forbidden, anonymize(actor:).code
          assert_nothing_written
        end
      end

      test "only a student account is deleted on request in this version: a teacher or a team account is refused" do
        [ TEACHER, MEMBER ].each do |target|
          assert_equal :forbidden, anonymize(target: target.public_id).code
          assert_nothing_written
        end
      end

      test "an unknown account is not found" do
        assert_equal :not_found, anonymize(target: "inconnu").code
        assert_nothing_written
      end

      test "an account already anonymized is a conflict, written once" do
        result = anonymize(target: GONE.public_id)

        assert_equal :conflict, result.code
        assert_equal({ base: [ :already_anonymized ] }, result.errors)
        assert_nothing_written
      end

      test "the date of the request is required, and never in the future" do
        [ [ "", :blank ], [ "pas une date", :blank ], [ "2026-10-03", :in_future ] ].each do |requested_on, error|
          result = anonymize(requested_on:)

          assert_equal :invalid, result.code
          assert_includes result.errors[:requested_on], error
          assert_nothing_written
        end
      end
    end
  end
end

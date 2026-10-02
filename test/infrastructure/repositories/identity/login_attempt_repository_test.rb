require "test_helper"

module Repositories
  module Identity
    class LoginAttemptRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = LoginAttemptRepository.new
        @now = Time.current.change(usec: 0)
      end

      def attempt(succeeded, minutes_ago, contact: "0101020304", kind: "pin")
        @repository.record(contact:, user_id: nil, ip: "10.0.0.1", succeeded:, kind:, at: @now - minutes_ago.minutes)
      end

      test "no attempt gives zero failures" do
        assert_equal Ports::Identity::LoginAttemptRepositoryPort::Failures.new(count: 0, last_failed_at: nil),
                     @repository.consecutive_failures(contact: "0101020304", kind: "pin")
      end

      test "failures count since the last success of the contact, for one kind" do
        attempt(false, 50)
        attempt(true, 40)
        attempt(false, 30)
        attempt(false, 20)
        attempt(false, 10, kind: "second_factor")
        attempt(false, 5, contact: "0509080706")

        failures = @repository.consecutive_failures(contact: "0101020304", kind: "pin")

        assert_equal [ 2, @now - 20.minutes ], [ failures.count, failures.last_failed_at ]
      end

      test "without any success, every failure counts" do
        attempt(false, 30)
        attempt(false, 20)

        assert_equal 2, @repository.consecutive_failures(contact: "0101020304", kind: "pin").count
      end

      test "a raw contact is cut to the column size" do
        long = "x" * 40
        attempt(false, 1, contact: long)

        assert_equal "x" * 20, Orm::LoginAttempt.last.contact
        assert_equal 1, @repository.consecutive_failures(contact: long, kind: "pin").count
      end

      test "an unknown kind is refused" do
        assert_raises(ArgumentError) { attempt(false, 1, kind: "sms") }
      end

      test "clear_failures lifts the lockout of every kind" do
        attempt(false, 3)
        attempt(false, 2, kind: "second_factor")
        attempt(true, 1)

        assert_equal 2, @repository.clear_failures(contact: "0101020304")
        assert_equal 0, @repository.consecutive_failures(contact: "0101020304", kind: "second_factor").count
        assert_equal 1, Orm::LoginAttempt.count
      end

      # ADR-0036 §4 : la suppression d'un compte efface ses tentatives et celles faites avec son numéro, pas celles des autres.
      test "destroy_all_for removes the attempts of the account and of its number, and nothing else" do
        user_id = create_student.id
        @repository.record(contact: "0101020304", user_id:, ip: "10.0.0.1", succeeded: true, kind: "pin", at: @now)
        @repository.record(contact: "0909090909", user_id:, ip: "10.0.0.2", succeeded: false, kind: "pin", at: @now)
        attempt(false, 5)
        attempt(false, 5, contact: "0505050505")

        assert_equal 3, @repository.destroy_all_for(user_id:, contact: "0101020304")
        assert_equal [ "0505050505" ], Orm::LoginAttempt.pluck(:contact)
        assert_equal 0, @repository.destroy_all_for(user_id: user_id + 1, contact: nil)
      end
    end
  end
end

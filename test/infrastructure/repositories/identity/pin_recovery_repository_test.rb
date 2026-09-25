require "test_helper"

module Repositories
  module Identity
    class PinRecoveryRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = PinRecoveryRepository.new
        @student = create_student
        @teacher = create_teacher
        @now = Time.current.change(usec: 0)
      end

      def issue(digest = "a" * 64)
        @repository.issue(user_id: @student.id, issued_by_id: @teacher.id, code_digest: digest, expires_at: @now + 15.minutes, at: @now)
      end

      test "issue stores the code and active_for maps it" do
        assert issue

        code = @repository.active_for(user_id: @student.id)

        assert_equal [ @student.id, "a" * 64, @now + 15.minutes, 0 ],
                     [ code.user_id, code.code_digest, code.expires_at, code.failed_attempts ]
        assert_equal :usable, code.status(now: @now)
      end

      test "issuing again revokes the previous code" do
        issue("a" * 64)
        issue("b" * 64)

        assert_equal "b" * 64, @repository.active_for(user_id: @student.id).code_digest
        assert_equal 2, Orm::PinRecoveryCode.where(user_id: @student.id).count
      end

      test "no active code is nil" do
        assert_nil @repository.active_for(user_id: @student.id)
      end

      test "record_failure counts and revokes the code at the fifth failure" do
        issue
        id = @repository.active_for(user_id: @student.id).id

        assert_equal [ 1, 2, 3, 4 ], Array.new(4) { @repository.record_failure(id:, at: @now) }
        assert @repository.active_for(user_id: @student.id)

        assert_equal 5, @repository.record_failure(id:, at: @now)
        assert_nil @repository.active_for(user_id: @student.id)
        assert_equal @now, Orm::PinRecoveryCode.find(id).revoked_at
      end

      test "consume marks the code used" do
        issue
        id = @repository.active_for(user_id: @student.id).id

        assert @repository.consume(id:, at: @now)
        assert_nil @repository.active_for(user_id: @student.id)
      end
    end
  end
end

require "test_helper"

module Repositories
  module Classroom
    class InviteCodeRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = InviteCodeRepository.new
        @student = create_student(classroom: create_classroom)
      end

      test "the code is created once, stable and well formed" do
        first = @repository.code_for(student_id: @student.id)
        second = @repository.code_for(student_id: @student.id)

        assert_predicate first, :success?
        assert_equal first.value, second.value
        assert Entities::Classroom::InviteCode.valid?(first.value)
        assert_equal 1, Orm::StudentInviteCode.where(student_id: @student.id).count
      end

      test "the code carries neither the id nor the public id" do
        code = @repository.code_for(student_id: @student.id).value

        assert_not_includes code, @student.public_id.to_s.downcase
        assert_not_includes code, @student.id.to_s
      end

      test "the inviter is found by code, written in any case" do
        code = @repository.code_for(student_id: @student.id).value

        assert_equal @student.id, @repository.inviter_for(code:)
        assert_equal @student.id, @repository.inviter_for(code: " #{code.upcase} ")
      end

      test "an anonymised student, an unknown or a malformed code designate nobody" do
        code = @repository.code_for(student_id: @student.id).value
        Orm::User.where(id: @student.id).update_all(anonymized_at: Time.current)

        assert_nil @repository.inviter_for(code:)
        assert_nil @repository.inviter_for(code: "zzzzzzzz")
        assert_nil @repository.inviter_for(code: "nope")
        assert_nil @repository.inviter_for(code: nil)
      end

      test "a collision is retried, three times at most" do
        other = create_student(classroom: create_classroom)
        taken = @repository.code_for(student_id: other.id).value
        codes = [ taken, taken, "abcdefgh" ]

        stub_method(Entities::Classroom::InviteCode, :generate, ->(**) { codes.shift }) do
          assert_equal "abcdefgh", @repository.code_for(student_id: @student.id).value
        end

        codes = [ taken, taken, taken ]
        third = create_student(classroom: create_classroom)
        stub_method(Entities::Classroom::InviteCode, :generate, ->(**) { codes.shift }) do
          result = @repository.code_for(student_id: third.id)

          assert_predicate result, :failure?
          assert_equal :unavailable, result.code
        end
      end

      test "a concurrent insertion for the same student returns the code that won the race" do
        winner = "abcdefgh"
        racing = lambda do |*|
          Orm::StudentInviteCode.create!(student_id: @student.id, code: winner)
          []
        end

        stub_method(Orm::StudentInviteCode, :insert, racing) do
          assert_equal winner, @repository.code_for(student_id: @student.id).value
        end
        assert_equal 1, Orm::StudentInviteCode.where(student_id: @student.id).count
      end
    end
  end
end

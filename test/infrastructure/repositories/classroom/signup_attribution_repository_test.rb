require "test_helper"

module Repositories
  module Classroom
    class SignupAttributionRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = SignupAttributionRepository.new
        @classroom = create_classroom
        @student = create_student(classroom: @classroom)
        @at = Time.zone.parse("2026-11-20 08:00")
      end

      test "records the source of a student" do
        result = @repository.record(student_id: @student.id, classroom_id: @classroom.id, source: "qr", inviter_id: nil, at: @at)

        assert_predicate result, :success?
        row = Orm::SignupAttribution.find_by!(student_id: @student.id)
        assert_equal [ "qr", @classroom.id, nil ], [ row.source, row.classroom_id, row.inviter_id ]
      end

      test "a second write leaves the first line unchanged" do
        @repository.record(student_id: @student.id, classroom_id: @classroom.id, source: "qr", inviter_id: nil, at: @at)
        other = create_classroom
        result = @repository.record(student_id: @student.id, classroom_id: other.id, source: "cold", inviter_id: nil, at: @at + 1.day)

        assert_predicate result, :success?
        assert_equal 1, Orm::SignupAttribution.where(student_id: @student.id).count
        row = Orm::SignupAttribution.find_by!(student_id: @student.id)
        assert_equal [ "qr", @classroom.id ], [ row.source, row.classroom_id ]
      end

      test "the inviter is kept for a student invite" do
        inviter = create_student(classroom: @classroom)
        @repository.record(student_id: @student.id, classroom_id: @classroom.id, source: "student_invite", inviter_id: inviter.id, at: @at)

        assert_equal inviter.id, Orm::SignupAttribution.find_by!(student_id: @student.id).inviter_id
      end

      test "the database refuses an inviter outside a student invite, a self invite and an unknown source" do
        inviter = create_student(classroom: @classroom)
        [ [ "qr", inviter.id ], [ "student_invite", @student.id ], [ "magic", nil ] ].each do |source, inviter_id|
          assert_raises(ActiveRecord::StatementInvalid) do
            Orm::SignupAttribution.transaction(requires_new: true) do
              @repository.record(student_id: @student.id, classroom_id: @classroom.id, source:, inviter_id:, at: @at)
            end
          end
        end
      end

      test "a deleted inviter leaves the student invite source" do
        inviter = create_student
        @repository.record(student_id: @student.id, classroom_id: @classroom.id, source: "student_invite", inviter_id: inviter.id, at: @at)
        Orm::User.where(id: inviter.id).delete_all

        row = Orm::SignupAttribution.find_by!(student_id: @student.id)
        assert_equal "student_invite", row.source
        assert_nil row.inviter_id
      end
    end
  end
end

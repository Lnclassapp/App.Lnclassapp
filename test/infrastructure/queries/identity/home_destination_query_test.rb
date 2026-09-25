require "test_helper"

module Queries
  module Identity
    class HomeDestinationQueryTest < ActiveSupport::TestCase
      def destination_of(user)
        Queries::Identity::HomeDestinationQuery.new.call(actor: Repositories::Identity::UserRepository.new.actor_for(user_id: user.id))
      end

      test "a student in an active primary classroom goes home" do
        assert_equal :student_home, destination_of(create_student(classroom: create_classroom))
      end

      test "a student without a classroom, or whose classroom is archived, waits on the pending page" do
        assert_equal :pending_account, destination_of(create_student)
        assert_equal :pending_account, destination_of(create_student(classroom: create_classroom(status: "archived")))
      end

      test "a student who left their classroom waits on the pending page" do
        student = create_student(classroom: create_classroom)
        Orm::ClassroomStudent.where(student:).update_all(left_at: Time.current)

        assert_equal :pending_account, destination_of(student)
      end

      test "a teacher goes home once onboarded, to their classrooms before" do
        assert_equal :teacher_home, destination_of(create_teacher)
        assert_equal :teacher_classrooms, destination_of(create_teacher(onboarded: false))
      end

      test "a teacher without a primary school waits on the pending page" do
        teacher = create_teacher
        Orm::TeacherSchool.where(teacher:).delete_all

        assert_equal :pending_account, destination_of(teacher)
      end

      test "the team goes to its area, the school management waits (V2)" do
        assert_equal :team_home, destination_of(create_team_member)
        assert_equal :pending_account, destination_of(create_user(role: "school_admin"))
      end
    end
  end
end

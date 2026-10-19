require "test_helper"

module UseCases
  module School
    # ME-13 to ME-15 (ADR-0094 §4.4, UDR-0099 §3.3), on the real repositories: leaving a school withdraws the teacher's
    # classrooms and archives his active assignments of that school only, promotes the oldest remaining school if it was
    # the primary one, records no departure (he may come back) and journals « teacher.left ».
    class LeaveSchoolTest < ActiveSupport::TestCase
      NOW = Time.zone.local(2026, 10, 16, 9)
      Clock = Data.define(:now)

      setup do
        @a = create_school(name: "Lycée moderne d'Abobo")
        @b = create_school(name: "Collège Saint-Michel")
        @c = create_school(name: "Collège Notre-Dame")
        @a1 = create_classroom(school: @a, name: "3ème 1")
        @b1 = create_classroom(school: @b, name: "4ème 2")
        @b2 = create_classroom(school: @b, name: "5ème 1")
        @teacher = create_teacher(school: @a, classrooms: [ @a1, @b1, @b2 ])
        add_teacher_school(@teacher, @b, at: 2.days.ago)
        @in_a = create_assignment(classroom: @a1, by: @teacher, due_on: Date.current + 2)
        @in_b = [ @b1, @b2 ].map { create_assignment(classroom: it, by: @teacher, due_on: Date.current + 2) }
      end

      def leave(school, actor: teacher_actor)
        LeaveSchool.new(schools: Repositories::School::SchoolRepository.new, teachings: Repositories::Classroom::TeachingRepository.new,
                        assignments: Repositories::Classroom::AssignmentRepository.new,
                        audit_log: Repositories::Identity::AuditLogRepository.new, policy: Policies::School::LeaveSchoolPolicy.new,
                        transaction: Repositories::Shared::Transaction.new, clock: Clock.new(NOW))
                   .call(actor:, school_public_id: school&.public_id)
      end

      def teacher_actor = Repositories::Identity::UserRepository.new.actor_for(user_id: @teacher.id)
      def school_ids = Orm::TeacherSchool.where(teacher: @teacher).order(:created_at).pluck(:school_id, :primary)

      test "ME-13: leaving B withdraws his classrooms and archives his assignments of B only; no departure; journaled" do
        result = leave(@b)

        assert_equal [ @b.id, 2, 2 ], result.value.then { [ it.school.id, it.classrooms_count, it.assignments_archived ] }
        assert_equal [ [ @a.id, true ] ], school_ids
        assert_equal [ @a1.id ], Orm::TeacherClassroom.where(teacher: @teacher).pluck(:classroom_id)
        assert_equal [ "active", "archived", "archived" ], [ @in_a, *@in_b ].map { it.reload.status }
        assert_not Orm::TeacherSchoolDeparture.exists?(teacher: @teacher)
        event = Orm::AuditEvent.find_by!(action: "teacher.left")
        assert_equal [ @teacher.id, @teacher.id, { "school_id" => @b.id, "classrooms_count" => 2, "assignments_archived" => 2 } ],
                     [ event.actor_id, event.subject_id, event.metadata ]
      end

      test "ME-14: leaving the primary school makes the oldest remaining one primary" do
        add_teacher_school(@teacher, @c, at: 1.day.ago)

        assert leave(@a).success?

        assert_equal [ [ @b.id, true ], [ @c.id, false ] ], school_ids
        assert_equal @b.id, teacher_actor.school_id
      end

      test "ME-15: the last school cannot be left, and nothing is written" do
        leave(@b)

        result = leave(@a)

        assert_equal [ :forbidden, { base: [ :last_school ] } ], [ result.code, result.errors ]
        assert_equal [ [ @a.id, true ] ], school_ids
        assert_equal "active", @in_a.reload.status
      end

      test "a school he does not belong to, or an unknown one, is not found; another role is refused" do
        assert_equal :not_found, leave(@c).code
        assert_equal :not_found, leave(nil).code
        assert_equal :forbidden, leave(@a, actor: Entities::Identity::Actor.new(user_id: 1, role: :student)).code
        assert_equal :forbidden, leave(@a, actor: nil).code
        assert_equal 2, school_ids.size
      end

      # Two devices at the same time: the policy read two schools, but the other device has already left one. The row
      # already gone, or no school left after this one, undoes everything.
      test "a leave raced by another device is undone: the row already gone, or no school left behind" do
        schools = Repositories::School::SchoolRepository.new
        ids = [ @a.id, @b.id, @c.id ]
        schools.define_singleton_method(:school_ids_for) { |teacher_id:| ids }
        use_case = LeaveSchool.new(schools:, teachings: Repositories::Classroom::TeachingRepository.new,
                                   assignments: Repositories::Classroom::AssignmentRepository.new,
                                   audit_log: Repositories::Identity::AuditLogRepository.new,
                                   policy: Policies::School::LeaveSchoolPolicy.new,
                                   transaction: Repositories::Shared::Transaction.new, clock: Clock.new(NOW))

        assert_equal :not_found, use_case.call(actor: teacher_actor, school_public_id: @c.public_id).code
        Orm::TeacherSchool.where(teacher: @teacher, school: @a).delete_all
        result = use_case.call(actor: teacher_actor, school_public_id: @b.public_id)

        assert_equal [ :forbidden, { base: [ :last_school ] } ], [ result.code, result.errors ]
        assert_equal [ [ @b.id, false ] ], school_ids
        assert_equal %w[active active], @in_b.map { it.reload.status }
        assert_not Orm::AuditEvent.exists?(action: "teacher.left")
      end
    end
  end
end

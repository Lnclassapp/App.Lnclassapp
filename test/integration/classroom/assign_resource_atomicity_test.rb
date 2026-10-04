require "test_helper"

# ADR-0072 §4.3, UDR-0062 §3.4: the days checked at the « Quels jours ? » step and the assignment are written in one
# transaction. When the assignment loses a race at the write (the active unique index refuses it), the days written just
# before are rolled back — the real adapters and PostgreSQL, no double: FakeTransaction only yields, it proves no rollback.
class Classroom::AssignResourceAtomicityTest < ActiveSupport::TestCase
  # A race lost between the read and the write: the active row appeared after `active_for` answered nil, and the real
  # `create` meets the partial unique index.
  class RacingAssignments < Repositories::Classroom::AssignmentRepository
    def active_for(classroom_id:, assignable:) = nil
  end

  setup do
    course = create_course(name: "Génétique")
    @classroom = create_classroom(name: "6ème 1", level: course.level)
    @teacher = create_teacher(classrooms: [ @classroom ])
    @exercise = create_exercise(essential: create_essential(course:), title: "Les phases")
    @actor = Entities::Identity::Actor.new(user_id: @teacher.id, role: :teacher, school_id: @classroom.school_id)
  end

  def assign(assignments)
    dto = Dtos::Classroom::AssignmentInput.new(classroom_public_id: @classroom.public_id, assignable_type: "Exercise",
                                               assignable_key: @exercise.public_id, weekdays: %w[1 4])
    UseCases::Classroom::AssignResource.new(
      classrooms: Repositories::Classroom::ClassroomRepository.new, assignments:,
      session_days: Repositories::Classroom::SessionDaysRepository.new, transaction: Repositories::Shared::Transaction.new,
      policy: Policies::Classroom::AssignPolicy.new, session_days_policy: Policies::Classroom::SetSessionDaysPolicy.new,
      clock: Time.zone
    ).call(actor: @actor, dto:)
  end

  def session_days = Orm::ClassroomSessionDay.where(teacher_id: @teacher.id, classroom_id: @classroom.id)

  test "a race lost after the days are written: :conflict, and no session day is left in the database" do
    existing = create_assignment(classroom: @classroom, assignable: @exercise, by: create_teacher(classrooms: [ @classroom ]))
    assert_not session_days.exists?

    result = assign(RacingAssignments.new)

    assert_equal [ :conflict, { base: [ :already_assigned ] } ], [ result.code, result.errors ]
    assert_not session_days.exists?, "les jours écrits avant le refus doivent être annulés"
    assert_equal 0, Orm::ClassroomSessionDay.count
    assert_equal [ existing.id ], Orm::ClassroomAssignment.pluck(:id)
  end

  test "without a race, the same call writes the days and the assignment together" do
    result = assign(Repositories::Classroom::AssignmentRepository.new)

    assert result.success?
    assert_equal [ 1, 4 ], session_days.order(:weekday).pluck(:weekday)
    assert_equal [ result.value.assignment.due_on ], Orm::ClassroomAssignment.where(assignable_id: @exercise.id).pluck(:due_on)
    assert_not_nil result.value.assignment.due_on
  end
end

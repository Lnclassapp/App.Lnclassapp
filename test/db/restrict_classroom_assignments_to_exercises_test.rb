require "test_helper"
require Rails.root.join("db/migrate/20261003100000_restrict_classroom_assignments_to_exercises").to_s

# ADR-0072 §4.1, grill Q7: the migration counts the course and essential assignments first, archived ones included, and
# stops with their number rather than lose one. Each test runs in the rolled back transaction of the test: PostgreSQL
# rolls the constraint changes back with it.
class RestrictClassroomAssignmentsToExercisesTest < ActiveSupport::TestCase
  def connection = ActiveRecord::Base.connection

  def migration = RestrictClassroomAssignmentsToExercises.new

  def migrate(direction) = ActiveRecord::Migration.suppress_messages { migration.migrate(direction) }

  def type_constraint
    connection.check_constraints("classroom_assignments").find { it.name == "classroom_assignments_type_values" }.expression
  end

  setup do
    @classroom = create_classroom
    @teacher = create_teacher(classrooms: [ @classroom ])
    migrate(:down) # the former constraint: Course, Essential and Exercise
  end

  def insert_assignment(assignable, status: "active")
    create_assignment(classroom: @classroom, assignable:, by: @teacher, status:)
  end

  test "on a base without course nor essential assignment, up keeps the exercises and accepts nothing else" do
    exercise = insert_assignment(create_exercise)

    migrate(:up)

    assert_match(/'Exercise'/, type_constraint)
    assert_no_match(/Course|Essential/, type_constraint)
    assert_equal "Exercise", exercise.reload.assignable_type
    assert_raises(ActiveRecord::CheckViolation) do
      connection.transaction(requires_new: true) { insert_assignment(create_course) }
    end
  end

  test "a course or essential assignment, even archived, makes up fail with their number and leaves everything intact" do
    course = insert_assignment(create_course)
    essential = insert_assignment(create_essential, status: "archived")
    insert_assignment(create_exercise)
    rows = -> { Orm::ClassroomAssignment.order(:id).pluck(:id, :assignable_type, :assignable_id, :status) }
    before_rows = rows.call
    before_constraint = type_constraint

    error = assert_raises(ActiveRecord::MigrationError) { migrate(:up) }

    assert_match(/\b2 course or essential assignment/, error.message)
    assert_match(/ADR-0072/, error.message)
    assert_equal before_rows, rows.call
    assert_equal before_constraint, type_constraint
    assert_equal [ "Course", "active" ], [ course.reload.assignable_type, course.status ]
    assert_equal [ "Essential", "archived" ], [ essential.reload.assignable_type, essential.status ]
  end

  test "down restores the three former types" do
    migrate(:up)
    migrate(:down)

    %w[Course Essential Exercise].each { assert_match(/'#{it}'/, type_constraint) }
  end
end

require "test_helper"

# ADR-0072 §4.2, §4.3 : la base refuse une échéance impossible et un jour de séance sans déclaration.
class ClassroomAssignmentsConstraintsTest < ActiveSupport::TestCase
  def connection = ActiveRecord::Base.connection

  def violates(error, &)
    assert_raises(error) { connection.transaction(requires_new: true, &) }
  end

  setup do
    @classroom = create_classroom
    @teacher = create_teacher(classrooms: [ @classroom ])
    @exercise = create_exercise
    # 23 h 30 à Abidjan (UTC+0, sans heure d'été) : la date locale de l'assignation est le samedi 3 octobre.
    @assigned_at = Time.utc(2026, 10, 3, 23, 30)
  end

  def assign(due_on)
    create_assignment(classroom: @classroom, assignable: @exercise, by: @teacher, assigned_at: @assigned_at, due_on:)
  end

  test "due_on est une date facultative" do
    column = connection.columns("classroom_assignments").find { it.name == "due_on" }

    assert_equal [ :date, true ], [ column.type, column.null ]
    assert_nil assign(nil).reload.due_on
  end

  test "une échéance du lendemain à une semaine plus tard est acceptée" do
    [ 1, 2, 7 ].each do |days|
      record = assign(Date.new(2026, 10, 3) + days)

      assert_equal Date.new(2026, 10, 3) + days, record.reload.due_on
      record.update_columns(status: "archived", archived_at: @assigned_at)
    end
  end

  test "une échéance le jour même, avant l'assignation ou à plus d'une semaine est refusée" do
    [ 0, -1, 8 ].each do |days|
      violates(ActiveRecord::CheckViolation) { assign(Date.new(2026, 10, 3) + days) }
    end
  end

  test "la date de l'assignation est lue à Abidjan, depuis l'heure stockée en UTC" do
    assert_match(/Africa\/Abidjan/, connection.check_constraints("classroom_assignments")
                                              .find { it.name == "classroom_assignments_due_on_within_a_week" }.expression)
  end

  def insert_day(weekday, teacher: @teacher, classroom: @classroom)
    Orm::ClassroomSessionDay.insert({ teacher_id: teacher.id, classroom_id: classroom.id, weekday:, created_at: Time.current })
  end

  test "un jour de séance va de 1 (lundi) à 6 (samedi), une fois par enseignant et par classe" do
    (1..6).each { insert_day(it) }

    assert_equal [ 1, 2, 3, 4, 5, 6 ], Orm::ClassroomSessionDay.where(teacher_id: @teacher.id).order(:weekday).pluck(:weekday)
    violates(ActiveRecord::CheckViolation) { insert_day(7) }
    violates(ActiveRecord::CheckViolation) { insert_day(0) }
    violates(ActiveRecord::RecordNotUnique) do
      connection.execute("INSERT INTO classroom_session_days (teacher_id, classroom_id, weekday, created_at) " \
                         "VALUES (#{@teacher.id}, #{@classroom.id}, 1, now())")
    end
  end

  test "un jour de séance sans déclaration d'enseignement est refusé, et la déclaration ne part pas avant ses jours" do
    violates(ActiveRecord::InvalidForeignKey) { insert_day(1, classroom: create_classroom(school: @classroom.school)) }
    violates(ActiveRecord::InvalidForeignKey) { insert_day(1, teacher: create_teacher) }

    insert_day(1)
    violates(ActiveRecord::InvalidForeignKey) do
      Orm::TeacherClassroom.where(teacher_id: @teacher.id, classroom_id: @classroom.id).delete_all
    end
  end

  test "les clés étrangères restreignent la suppression, sans cascade nouvelle (ADR-0036)" do
    foreign_keys = connection.foreign_keys("classroom_session_days")

    assert_includes foreign_keys.map { [ it.to_table, it.column ] }, [ "teacher_classrooms", %w[teacher_id classroom_id] ]
    assert_includes foreign_keys.map { [ it.to_table, it.column ] }, [ "users", "teacher_id" ]
    assert(foreign_keys.all? { it.on_delete == :restrict })
  end
end

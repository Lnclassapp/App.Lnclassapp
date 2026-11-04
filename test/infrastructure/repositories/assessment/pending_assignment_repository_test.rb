require "test_helper"

# prepare-interros-cahier, Lot C (CA-17) : un devoir est « à rendre » tant que l'exercice est assigné, de façon active, à la classe principale
# de l'élève et qu'aucune copie terminée n'est rattachée à cette assignation.
class Repositories::Assessment::PendingAssignmentRepositoryTest < ActiveSupport::TestCase
  setup do
    @course = create_course
    @exercise = create_exercise(course: @course, questions: 1)
    @classroom = create_classroom(level: @course.level, series: @course.series)
    @student = create_student(classroom: @classroom)
    @repository = Repositories::Assessment::PendingAssignmentRepository.new
  end

  def pending(exercises = [ @exercise ], student: @student)
    @repository.pending_exercise_public_ids(student_id: student.id, exercise_public_ids: exercises.map(&:public_id))
  end

  test "un exercice assigné à la classe de l'élève et pas rendu est à rendre" do
    create_assignment(classroom: @classroom, assignable: @exercise)

    assert_equal Set[@exercise.public_id], pending
  end

  test "aucun exercice demandé, aucune assignation, ou un autre exercice : rien à rendre" do
    other = create_exercise(course: @course, questions: 1)
    create_assignment(classroom: @classroom, assignable: other)

    assert_empty pending([])
    assert_empty pending
    assert_equal Set[other.public_id], pending([ @exercise, other ])
  end

  test "une copie terminée rattachée à l'assignation la rend ; une copie d'entraînement, non" do
    assignment = create_assignment(classroom: @classroom, assignable: @exercise)
    create_exercise_session(student: @student, exercise: @exercise, status: "completed")
    assert_equal Set[@exercise.public_id], pending

    create_exercise_session(student: @student, exercise: @exercise, status: "completed", classroom_assignment_id: assignment.id)

    assert_empty pending
  end

  test "une assignation archivée, d'une autre classe, ou la classe quittée : rien à rendre" do
    create_assignment(classroom: @classroom, assignable: @exercise, status: "archived")
    create_assignment(classroom: create_classroom(level: @course.level, series: @course.series), assignable: @exercise)
    assert_empty pending

    assert_empty pending(student: create_student)

    create_assignment(classroom: @classroom, assignable: @exercise)
    Orm::ClassroomStudent.where(student: @student).update_all(left_at: Time.current)
    assert_empty pending
  end
end

require "test_helper"

# ADR-XXXX-suppression-d-une-lecon-sans-activite-eleve §4.3-4.4 : un élève qui commence un exercice, ou un enseignant qui l'envoie à
# sa classe, pendant la suppression de la leçon attend la fin de la suppression puis échoue ; aucune trace orpheline. Hors transaction
# de test : chaque fil a la sienne.
class CourseDeletionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  PAUSE = 0.4

  setup do
    @level = create_level
    @material = create_material
    @author = create_user(role: "team", team_role: "content")
    @course = create_course(level: @level, material: @material, author: @author)
    @exercise = create_exercise(essential: create_essential(course: @course))
    @student = create_user(role: "student")
    @teacher = create_user(role: "teacher")
    @drena = create_drena
    @school = create_school(drena: @drena)
    @classroom = create_classroom(school: @school, level: @level)
  end

  teardown do
    Orm::ClassroomAssignment.where(classroom_id: @classroom.id).delete_all
    Orm::ExerciseSession.where(student_id: @student.id).delete_all
    exercise_ids = Orm::Exercise.where(course_id: @course.id).pluck(:id)
    question_ids = Orm::Question.where(exercise_id: exercise_ids).pluck(:id)
    Orm::Answer.where(question_id: question_ids).delete_all
    Orm::Question.where(id: question_ids).delete_all
    Orm::Exercise.where(id: exercise_ids).delete_all
    Orm::Essential.where(course_id: @course.id).delete_all
    Orm::RichTextRow.where(record_type: "Orm::Course", record_id: @course.id).delete_all
    Orm::Course.where(id: @course.id).delete_all
    @classroom.delete
    @school.delete
    @drena.delete
    Orm::User.where(id: [ @author.id, @student.id, @teacher.id ]).delete_all
    @level.delete
    @material.delete
  end

  # La suppression prend ses verrous, signale, attend PAUSE puis supprime : l'autre fil écrit pendant ce temps.
  def delete_holding(locked)
    ActiveRecord::Base.connection_pool.with_connection do
      Orm::Course.transaction do
        repository = Repositories::Catalog::CourseRepository.new
        activity = repository.lock_for_deletion(id: @course.id)
        locked << true
        sleep PAUSE
        repository.delete(id: @course.id) unless activity.any?
      end
    end
  end

  def concurrently(writer)
    locked = Queue.new
    deletion = Thread.new { delete_holding(locked) }
    other = Thread.new do
      locked.pop
      ActiveRecord::Base.connection_pool.with_connection { writer.call }
    end
    [ deletion.value, other.value ]
  end

  test "a session started while the lesson is being deleted waits, then fails on the missing exercise; nothing orphan" do
    _, started = concurrently(lambda do
      Orm::ExerciseSession.create!(student_id: @student.id, exercise_id: @exercise.id, status: "started", question_count: 2,
                                   started_at: Time.current)
      :written
    rescue ActiveRecord::InvalidForeignKey
      :refused
    end)

    assert_equal :refused, started
    assert_not Orm::Course.exists?(@course.id)
    assert_equal 0, Orm::ExerciseSession.where(student_id: @student.id).count
  end

  test "an assignment sent while the lesson is being deleted waits, then is refused as not found; nothing orphan" do
    assignable = Entities::Classroom::Assignable.new(type: "Exercise", id: @exercise.id, key: @exercise.public_id, name: nil)
    assignment = Entities::Classroom::Assignment.new(id: nil, public_id: nil, classroom_id: @classroom.id, assignable:, status: "active",
                                                     assigned_by_id: @teacher.id, assigned_at: Time.current, archived_at: nil, due_on: nil,
                                                     batch_public_id: nil)

    _, sent = concurrently(-> { Repositories::Classroom::AssignmentRepository.new.create(assignment:) })

    assert_equal :not_found, sent.code
    assert_not Orm::Course.exists?(@course.id)
    assert_equal 0, Orm::ClassroomAssignment.where(classroom_id: @classroom.id).count
  end
end

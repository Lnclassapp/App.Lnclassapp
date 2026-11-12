require "test_helper"

# hors-connexion Lot B2 : une ligne par (élève, exercice), la première remise n'est jamais reculée ni avancée.
class Repositories::Assessment::OfflinePackDeliveryRepositoryTest < ActiveSupport::TestCase
  setup do
    @course = create_course
    @exercise = create_exercise(course: @course, questions: 1)
    @student = create_student(classroom: create_classroom(level: @course.level, series: @course.series))
    @repository = Repositories::Assessment::OfflinePackDeliveryRepository.new
    @first = Time.utc(2026, 11, 12, 8, 0, 0)
  end

  test "la première remise crée la ligne, première et dernière à la même heure" do
    @repository.record(student_id: @student.id, exercise_id: @exercise.id, at: @first)

    row = Orm::OfflinePackDelivery.find_by!(student_id: @student.id, exercise_id: @exercise.id)
    assert_equal [ @first, @first ], [ row.first_delivered_at, row.last_delivered_at ]
    assert_equal @first, @repository.first_delivered_at(student_id: @student.id, exercise_id: @exercise.id)
  end

  test "une seconde remise avance la dernière et garde la première" do
    @repository.record(student_id: @student.id, exercise_id: @exercise.id, at: @first)

    assert_no_difference -> { Orm::OfflinePackDelivery.count } do
      @repository.record(student_id: @student.id, exercise_id: @exercise.id, at: @first + 1.day)
    end

    row = Orm::OfflinePackDelivery.find_by!(student_id: @student.id, exercise_id: @exercise.id)
    assert_equal [ @first, @first + 1.day ], [ row.first_delivered_at, row.last_delivered_at ]
  end

  test "une remise plus ancienne que la première ne la recule pas en arrière de la dernière : la plus ancienne reste la première" do
    @repository.record(student_id: @student.id, exercise_id: @exercise.id, at: @first)
    @repository.record(student_id: @student.id, exercise_id: @exercise.id, at: @first - 1.hour)

    row = Orm::OfflinePackDelivery.find_by!(student_id: @student.id, exercise_id: @exercise.id)
    assert_equal [ @first - 1.hour, @first ], [ row.first_delivered_at, row.last_delivered_at ]
  end

  test "sans remise, la première est nil ; un autre élève ou exercice n'est pas touché" do
    other = create_exercise(course: @course, questions: 1)
    @repository.record(student_id: @student.id, exercise_id: @exercise.id, at: @first)

    assert_nil @repository.first_delivered_at(student_id: @student.id, exercise_id: other.id)
  end
end

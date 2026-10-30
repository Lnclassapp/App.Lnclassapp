require "test_helper"

# ADR-XXXX sujets-de-devoir §4 et §6 : un exercice de sujet n'a pas de notion, et un indice a de 1 à 400 caractères.
class ExerciseSubjectConstraintTest < ActiveSupport::TestCase
  setup do
    @course = create_course
    @subject = create_subject(course: @course)
  end

  test "un exercice de sujet sans notion est accepté" do
    exercise = create_exercise(course: @course, lesson_wide: true, subject: @subject)

    assert_equal @subject.id, exercise.reload.subject_id
    assert_nil exercise.essential_id
  end

  test "la base refuse un exercice rattaché à un sujet et à une notion" do
    essential = create_essential(course: @course)

    error = assert_raises(ActiveRecord::StatementInvalid) { create_exercise(essential:, subject: @subject) }

    assert_match(/exercises_subject_without_essential/, error.message)
  end

  test "la base refuse aussi de rattacher à un sujet un exercice qui a déjà une notion" do
    exercise = create_exercise(essential: create_essential(course: @course))

    assert_raises(ActiveRecord::StatementInvalid) { exercise.update_columns(subject_id: @subject.id) }
  end

  test "deux sujets d'un cours ne partagent pas leur position" do
    assert_raises(ActiveRecord::RecordNotUnique) { create_subject(course: @course, position: @subject.position) }
  end

  test "l'indice : nul, ou de 1 à 400 caractères après nettoyage" do
    assert_nil create_exercise(course: @course).hint
    assert_equal "Pense à Thalès.", create_exercise(course: @course, hint: "Pense à Thalès.").hint
    assert_equal 400, create_exercise(course: @course, hint: "a" * 400).hint.size

    assert_raises(ActiveRecord::StatementInvalid) { create_exercise(course: @course, hint: "   ") }
    assert_raises(ActiveRecord::StatementInvalid) { create_exercise(course: @course, hint: "a" * 401) }
  end

  test "l'exercice d'un cours sait ses sujets, dans l'ordre" do
    second = create_subject(course: @course, position: 2)

    assert_equal [ @subject, second ], @course.subjects.to_a
  end
end

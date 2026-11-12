require "test_helper"

# hors-connexion, Lot 0 (ADR §4.5, menace R2) : une copie hors ligne n'entre qu'une fois par élève.
class Orm::ExerciseSessionTest < ActiveSupport::TestCase
  UUID = "3f2b8a1e-5c4d-4e6f-9a7b-1c2d3e4f5a6b".freeze

  setup do
    @student = create_student
    @exercise = create_exercise(questions: 1)
  end

  def completed(student: @student, **attributes)
    create_exercise_session(student:, exercise: @exercise, status: "completed", **attributes)
  end

  test "deux copies du même élève ne partagent pas un identifiant de copie" do
    completed(client_copy_id: UUID, received_at: Time.current)

    assert_raises(ActiveRecord::RecordNotUnique) { completed(client_copy_id: UUID, received_at: Time.current) }
  end

  test "le même identifiant chez deux élèves, et plusieurs copies sans identifiant, sont permis" do
    completed(client_copy_id: UUID)
    completed(student: create_student, client_copy_id: UUID)
    2.times { completed }

    assert_equal 4, Orm::ExerciseSession.where(exercise: @exercise).count
  end

  test "les colonnes sont nulles par défaut : une copie en ligne n'a ni identifiant ni heure de réception" do
    session = completed

    assert_nil session.reload.client_copy_id
    assert_nil session.received_at
  end
end

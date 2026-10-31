require "test_helper"

# ADR sujets-de-devoir (ajout du 2026-10-30) : classroom_assignments.batch_public_id relie les assignations d'un même envoi.
class ClassroomAssignmentsBatchTest < ActiveSupport::TestCase
  def connection = ActiveRecord::Base.connection

  test "batch_public_id est une chaîne de 14 caractères facultative" do
    column = connection.columns("classroom_assignments").find { it.name == "batch_public_id" }

    assert_not_nil column
    assert_equal [ :string, 14, true ], [ column.type, column.limit, column.null ]
    assert_nil create_assignment.reload.batch_public_id
  end

  test "un envoi rassemble ses assignations, une valeur trop longue est refusée" do
    classroom = create_classroom
    teacher = create_teacher(classrooms: [ classroom ])
    batch = Array.new(2) { create_assignment(classroom:, by: teacher, batch_public_id: "Ab3dEf5hJk7mNp") }

    assert_equal batch.map(&:id).sort, Orm::ClassroomAssignment.where(classroom_id: classroom.id, batch_public_id: "Ab3dEf5hJk7mNp").ids.sort
    assert_raises(ActiveRecord::ValueTooLong) { create_assignment(batch_public_id: "x" * 15) }
  end

  test "l'index relie la classe et l'envoi" do
    index = connection.indexes("classroom_assignments").find { it.columns == %w[classroom_id batch_public_id] }

    assert_not_nil index
    assert_not index.unique
  end
end

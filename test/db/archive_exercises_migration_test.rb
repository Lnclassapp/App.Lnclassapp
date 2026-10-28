require "test_helper"
require Rails.root.join("db/migrate/20261028090100_archive_exercises_before_lesson_redesign").to_s

# CA-30 : les exercices créés avant le chantier sont tous archivés, avec leurs assignations ; leurs sessions restent lisibles.
class ArchiveExercisesMigrationTest < ActiveSupport::TestCase
  def migrate(direction) = ActiveRecord::Migration.suppress_messages { ArchiveExercisesBeforeLessonRedesign.new.migrate(direction) }

  test "tous les exercices, publiés ou brouillons, sont archivés avec leur date" do
    published = create_exercise
    draft = create_exercise(status: "draft")
    already = create_exercise(status: "archived")

    migrate(:up)

    assert_equal %w[archived archived archived], [ published, draft, already ].map { it.reload.status }
    assert [ published, draft ].all? { it.reload.archived_at.present? }
  end

  test "les assignations actives sont archivées, les sessions restent lisibles" do
    classroom = create_classroom
    teacher = create_teacher(classrooms: [ classroom ])
    exercise = create_exercise
    assignment = create_assignment(classroom:, assignable: exercise, by: teacher)
    session = create_exercise_session(exercise:, status: "completed")

    migrate(:up)

    assert_equal "archived", assignment.reload.status
    assert_not_nil assignment.archived_at
    assert_equal "completed", session.reload.status
  end

  test "la migration ne se rejoue pas à l'envers" do
    assert_raises(ActiveRecord::IrreversibleMigration) { migrate(:down) }
  end
end

require "test_helper"
require Rails.root.join("db/migrate/20261028090000_attach_exercises_to_courses").to_s

# refonte-page-lecon, Lot 0 : l'exercice appartient à sa leçon. `down` ramène le schéma d'avant (positions par notion) ;
# rejouer `up` dessus prouve le remplissage de `course_id` et la renumérotation par leçon.
class AttachExercisesToCoursesMigrationTest < ActiveSupport::TestCase
  self.use_transactional_tests = true

  def migrate(direction) = ActiveRecord::Migration.suppress_messages { AttachExercisesToCourses.new.migrate(direction) }

  teardown { Orm::Exercise.reset_column_information }

  test "up : course_id reprend la leçon de la notion, les positions se suivent de 1 à n par leçon sans collision" do
    course = create_course
    other = create_course
    second = create_essential(course:, position: 2)
    first = create_essential(course:, position: 1)
    elsewhere = create_essential(course: other)
    a = create_exercise(essential: second)
    b = create_exercise(essential: first)
    c = create_exercise(essential: first)
    d = create_exercise(essential: elsewhere)

    migrate(:down)
    ids = [ a, b, c, d ].map(&:id)
    assert_equal [ 1, 1, 2, 1 ], select_positions(ids)
    migrate(:up)

    rows = ActiveRecord::Base.connection.select_rows("SELECT id, course_id, position FROM exercises WHERE id IN (#{ids.join(',')})")
                           .to_h { |id, course_id, position| [ id, [ course_id, position ] ] }
    # La notion 1 passe avant la notion 2, puis l'ordre d'avant dans chaque notion.
    assert_equal [ [ course.id, 3 ], [ course.id, 1 ], [ course.id, 2 ], [ other.id, 1 ] ], ids.map { rows.fetch(it) }
  end

  test "down refuse de s'exécuter s'il existe un exercice de toute la leçon" do
    create_exercise(lesson_wide: true)

    assert_raises(ActiveRecord::IrreversibleMigration) { migrate(:down) }
  end

  def select_positions(ids)
    ActiveRecord::Base.connection.select_values("SELECT position FROM exercises WHERE id IN (#{ids.join(',')}) ORDER BY array_position(ARRAY[#{ids.join(',')}]::bigint[], id)")
  end
end

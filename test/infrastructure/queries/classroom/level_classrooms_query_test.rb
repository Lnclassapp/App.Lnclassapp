require "test_helper"

# IL-04, IL-05, IL-06 (ADR-0085 §4.2, UDR-0081 §3.3): the classrooms list of the cascade. Only the active classrooms of
# the current year, of this level, in this active school, in natural order; each one shows its name and whether it is
# full — never its headcount, its ceiling, a teacher, a student nor its link token.
class Queries::Classroom::LevelClassroomsQueryTest < ActiveSupport::TestCase
  setup do
    @school = create_school(name: "Lycée Moderne de Cocody")
    @level = create_level(name: "3ème")
    @deux = create_classroom(school: @school, level: @level, name: "3e 2")
    @dix = create_classroom(school: @school, level: @level, name: "3e 10")
    @un = create_classroom(school: @school, level: @level, name: "3e 1", max_students: 2)
  end

  def classrooms(school_public_id: @school.public_id, level_slug: @level.slug, **options)
    Queries::Classroom::LevelClassroomsQuery.new.call(school_public_id:, level_slug:, **options)
  end

  test "IL-04: the active classrooms of the level in this school, « 3e 2 » before « 3e 10 »" do
    assert_equal [ [ @un.public_id, "3e 1" ], [ @deux.public_id, "3e 2" ], [ @dix.public_id, "3e 10" ] ],
                 classrooms.map { [ it.public_id, it.name ] }
  end

  test "IL-04: each classroom shows its name and « full », never a headcount, a teacher, a student nor its token" do
    create_teacher(classrooms: [ @un ], last_name: "Yao")
    create_student(classroom: @un, last_name: "Bamba")

    assert_equal %i[public_id name full], Queries::Classroom::LevelClassroomsQuery::Row.members
    values = classrooms.flat_map { it.to_h.values }
    [ "Yao", "Bamba", @un.reload.link_token, 1, 2, 80 ].each { assert_not_includes values, it }
  end

  test "IL-05: a classroom whose active headcount reaches its ceiling is full; a student who left does not count" do
    create_student(classroom: @un)
    gone = create_student(classroom: @un)

    assert classrooms.first.full

    Orm::ClassroomStudent.where(student: gone).update!(left_at: Time.current)

    assert_not classrooms.first.full
    assert_not classrooms.last.full
  end

  test "IL-06, IL-07: archived classrooms, those of another year, level or school are not offered" do
    create_classroom(school: @school, level: @level, name: "3e 4", status: "archived")
    create_classroom(school: @school, level: @level, name: "3e 5", school_year: "2020-2021")
    create_classroom(school: @school, level: create_level, name: "6e 1")
    create_classroom(school: create_school, level: @level, name: "3e 6")

    assert_equal [ "3e 1", "3e 2", "3e 10" ], classrooms.map(&:name)
  end

  test "IL-06: a level without an active classroom gives none" do
    assert_empty classrooms(level_slug: create_level.slug)
    assert_empty classrooms(level_slug: nil)
  end

  test "ADR-0085 §4.2: a draft or inactive school, or an unknown one, gives no classroom" do
    assert_empty classrooms(school_public_id: "sch-inconnu")

    %w[draft inactive].each do |status|
      @school.update!(status:)

      assert_empty classrooms, status
    end
  end

  test "the school year can be given" do
    create_classroom(school: @school, level: @level, name: "3e 7", school_year: "2020-2021")

    assert_equal [ "3e 7" ], classrooms(school_year: "2020-2021").map(&:name)
  end
end

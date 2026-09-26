require "test_helper"

# CL-08, ID-07 (ADR-0041, UDR-0009): the preview of /c/<code> names the classroom, its level and its school, and nothing more.
class Queries::Classroom::JoinPreviewQueryTest < ActiveSupport::TestCase
  setup do
    school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school:, level: create_level(name: "6ème"), name: "6ème 1", join_code: "kfm37")
  end

  def preview(code) = Queries::Classroom::JoinPreviewQuery.new.call(code:)

  test "the code, typed in any case and with spaces, gives the classroom, level and school names" do
    row = preview(" Kfm 37 ")

    assert_equal [ "6ème 1", "Lycée Classique d'Abidjan", "6ème" ], [ row.classroom_name, row.school_name, row.level_name ]
  end

  test "the row reveals no identifier, no headcount and no teacher" do
    create_teacher(classrooms: [ @classroom ])
    create_student(classroom: @classroom)

    assert_equal %i[classroom_name school_name level_name], Queries::Classroom::JoinPreviewQuery::Row.members
    assert_not_includes preview("kfm37").to_h.values, @classroom.public_id
  end

  test "an unknown, blank or replaced code gives nil" do
    assert_nil preview("zzz99")
    assert_nil preview("")
    assert_nil preview(nil)

    @classroom.update!(join_code: "abc23")

    assert_nil preview("kfm37")
  end

  test "a classroom whose code was closed is never found through a blank code" do
    @classroom.update!(join_code: nil)

    assert_nil preview("")
  end
end

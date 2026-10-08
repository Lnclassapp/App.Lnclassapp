require "test_helper"

# CL-08, ID-07 (ADR-0041, UDR-0009): the preview of /c/<code> names the classroom, its level and its school, and nothing more.
# IL-08, IL-09 (ADR-0085 §4.1, UDR-0081 §3.4): the preview of /c/<token> says the same three names, and whether the
# classroom is full; an unknown or replaced token, an archived classroom or a school that is not active gives nil.
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

  def link(token) = Queries::Classroom::JoinPreviewQuery.new.link(token:)

  test "IL-08: the link token gives the classroom, level and school names, and « not full »" do
    row = link(@classroom.reload.link_token)

    assert_equal [ "6ème 1", "Lycée Classique d'Abidjan", "6ème", false ],
                 [ row.classroom_name, row.school_name, row.level_name, row.full ]
  end

  test "IL-08: the link row reveals no identifier, no headcount, no teacher, no token and no code" do
    create_teacher(classrooms: [ @classroom ], last_name: "Yao")
    create_student(classroom: @classroom, last_name: "Bamba")
    token = @classroom.reload.link_token

    assert_equal %i[classroom_name school_name level_name full], Queries::Classroom::JoinPreviewQuery::LinkRow.members
    values = link(token).to_h.values
    [ @classroom.public_id, token, "kfm37", "Yao", "Bamba", 1, 80 ].each { assert_not_includes values, it }
  end

  test "IL-05: a classroom whose active headcount reaches its ceiling is full" do
    @classroom.update!(max_students: 1)
    student = create_student(classroom: @classroom)

    assert link(@classroom.reload.link_token).full

    Orm::ClassroomStudent.where(student:).update!(left_at: Time.current)

    assert_not link(@classroom.link_token).full
  end

  test "IL-09: an unknown or replaced token, an archived classroom or a school that is not active gives nil" do
    token = @classroom.reload.link_token

    assert_nil link("cccccccccccc")
    assert_nil link(nil)
    assert_nil link("kfm37")

    @classroom.update!(status: "archived", archived_at: Time.current)
    assert_nil link(token)

    @classroom.update!(status: "active", archived_at: nil)
    %w[draft inactive].each do |status|
      @classroom.school.update!(status:)
      assert_nil link(token), status
    end

    @classroom.school.update!(status: "active")
    @classroom.update!(link_token: "ffffffffffff")
    assert_nil link(token)
    assert_equal "6ème 1", link("ffffffffffff").classroom_name
  end
end

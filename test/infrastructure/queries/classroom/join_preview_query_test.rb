require "test_helper"

# IL-08, IL-09 (ADR-0085 §4.1, UDR-0081 §3.4): the preview of /c/<token> names the classroom, its level and its school,
# and whether the classroom is full, nothing more (ADR-0041); an unknown or replaced token or a school that is not
# active gives nil; an archived classroom answers with its names and archived: true (ADR-0088), so the page can say why.
class Queries::Classroom::JoinPreviewQueryTest < ActiveSupport::TestCase
  setup do
    school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school:, level: create_level(name: "6ème"), name: "6ème 1")
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

    assert_equal %i[classroom_name school_name level_name full archived], Queries::Classroom::JoinPreviewQuery::LinkRow.members
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

  test "IL-09: an unknown or replaced token or a school that is not active gives nil" do
    token = @classroom.reload.link_token

    assert_nil link("cccccccccccc")
    assert_nil link(nil)
    assert_nil link("kfm37")

    %w[draft inactive].each do |status|
      @classroom.school.update!(status:)
      assert_nil link(token), status
    end

    @classroom.school.update!(status: "active")
    @classroom.update!(link_token: "ffffffffffff")
    assert_nil link(token)
    assert_equal "6ème 1", link("ffffffffffff").classroom_name
  end

  test "ADR-0088: the link of an archived classroom gives its names with archived: true, not full; restored, it is as before" do
    token = @classroom.reload.link_token
    repository = Repositories::Classroom::ClassroomRepository.new

    repository.archive(id: @classroom.id, at: Time.current)
    row = link(token)

    assert_equal [ "6ème 1", "Lycée Classique d'Abidjan", "6ème", false, true ],
                 [ row.classroom_name, row.school_name, row.level_name, row.full, row.archived ]
    assert_equal token, @classroom.reload.link_token

    @classroom.school.update!(status: "inactive")
    assert_nil link(token)

    @classroom.school.update!(status: "active")
    repository.restore(id: @classroom.id, at: Time.current)
    assert_not link(token).archived
  end
end

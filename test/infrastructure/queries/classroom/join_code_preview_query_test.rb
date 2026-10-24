require "test_helper"

# CA-B2, CA-B3 (ADR code-de-classe-a-six-caracteres §4.4): the preview of a classroom code names the classroom, its level and
# its school (acronym, else name), and whether the classroom is full, nothing more; an unknown code, an archived classroom,
# and a school that is not active give the same nil.
class Queries::Classroom::JoinCodePreviewQueryTest < ActiveSupport::TestCase
  setup do
    @school = create_school(name: "Collège Moderne 1 de Tiassalé")
    @classroom = create_classroom(school: @school, level: create_level(name: "3ème"), name: "3e B")
    @code = @classroom.reload.join_code
  end

  def code(value) = Queries::Classroom::JoinCodePreviewQuery.new.code(code: value)

  test "CA-B2: the code gives the classroom, level and school names, and « not full »" do
    row = code(@code)

    assert_equal [ "3e B", "3ème", "Collège Moderne 1 de Tiassalé", false ],
                 [ row.classroom_name, row.level_name, row.school_label, row.full ]
  end

  test "CA-B2: the school is shown by its acronym when it has one" do
    @school.update!(sigle: "CM1 Tiassalé")

    assert_equal "CM1 Tiassalé", code(@code).school_label
  end

  test "CA-B2: the row reveals no identifier, no headcount, no teacher, no student, no token and no code" do
    create_teacher(classrooms: [ @classroom ], last_name: "Yao")
    create_student(classroom: @classroom, last_name: "Bamba")

    assert_equal %i[classroom_name level_name school_label full], Queries::Classroom::JoinCodePreviewQuery::CodeRow.members
    values = code(@code).to_h.values
    [ @classroom.public_id, @classroom.link_token, @code, "Yao", "Bamba", 1, 80 ].each { assert_not_includes values, it }
  end

  test "the code is typed as the teacher writes it: capitals, spaces, a dash" do
    typed = "#{@code[0, 3]} #{@code[3, 3]}".upcase

    assert_equal "3e B", code(typed).classroom_name
    assert_equal "3e B", code("#{@code[0, 3]}-#{@code[3, 3]}").classroom_name
  end

  test "a classroom whose active headcount reaches its ceiling is full" do
    @classroom.update!(max_students: 1)
    student = create_student(classroom: @classroom)

    assert code(@code).full

    Orm::ClassroomStudent.where(student:).update!(left_at: Time.current)

    assert_not code(@code).full
  end

  test "CA-B3: an unknown code, a malformed one, nil, an archived classroom and a school that is not active all give nil" do
    assert_nil code("zzzzzz")
    assert_nil code("abc")
    assert_nil code("abcdefg")
    assert_nil code("i0o1l!")
    assert_nil code(nil)
    assert_nil code("")

    @classroom.update!(status: "archived", archived_at: Time.current)
    assert_nil code(@code)

    @classroom.update!(status: "active", archived_at: nil)
    assert code(@code)

    %w[draft inactive].each do |status|
      @school.update!(status:)
      assert_nil code(@code), status
    end
  end

  test "the old code of a classroom whose link and code were changed is unknown" do
    Repositories::Classroom::ClassroomRepository.new.regenerate_link_and_code(id: @classroom.id)

    assert_nil code(@code)
    assert code(@classroom.reload.join_code)
  end
end

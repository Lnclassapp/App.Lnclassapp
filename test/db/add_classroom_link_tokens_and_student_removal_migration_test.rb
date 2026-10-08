require "test_helper"
require Rails.root.join("db/migrate/20261007110000_add_classroom_link_tokens_and_student_removal").to_s

# ADR-0085 §4.1, §4.4, §4.5 (IL-22): on a live database, every existing classroom receives its link token and every
# existing membership the historical arrival channel, « code ». Each test runs in the rolled back transaction of the
# test: PostgreSQL rolls the columns back with it.
class AddClassroomLinkTokensAndStudentRemovalMigrationTest < ActiveSupport::TestCase
  MODELS = [ Orm::Classroom, Orm::ClassroomStudent ].freeze

  def connection = ActiveRecord::Base.connection

  def migrate(direction)
    changing_schema do
      ActiveRecord::Migration.suppress_messages { AddClassroomLinkTokensAndStudentRemoval.new.migrate(direction) }
    end
    MODELS.each(&:reset_column_information)
  end

  teardown { MODELS.each(&:reset_column_information) }

  test "IL-22: every existing classroom receives its own link token, 12 hexadecimal characters" do
    classroom_ids = Array.new(3) { create_classroom.id }

    migrate(:down)
    assert_not Orm::Classroom.column_names.include?("link_token")

    migrate(:up)
    tokens = Orm::Classroom.where(id: classroom_ids).pluck(:link_token)
    assert_equal 3, tokens.uniq.size
    assert(tokens.all? { it.match?(/\A[0-9a-f]{12}\z/) }, tokens.inspect)
    assert_equal [ false, 12 ], Orm::Classroom.columns_hash["link_token"].then { [ it.null, it.limit ] }
    assert(connection.indexes(:classrooms).any? { it.unique && it.columns == [ "link_token" ] })
  end

  test "IL-22: every existing membership keeps its classroom and receives the channel code, then the default goes" do
    classroom = create_classroom
    student = create_student(classroom:)

    migrate(:down)
    assert_empty Orm::ClassroomStudent.column_names & %w[joined_via removed_at removed_by_id]

    migrate(:up)
    membership = Orm::ClassroomStudent.find_by!(student_id: student.id)
    assert_equal [ classroom.id, "code", nil, nil, nil ],
                 [ membership.classroom_id, membership.joined_via, membership.left_at, membership.removed_at, membership.removed_by_id ]
    column = Orm::ClassroomStudent.columns_hash["joined_via"]
    assert_equal [ false, nil ], [ column.null, column.default ], "plus de défaut après la reprise"
  end

  test "running up again changes no token and no channel already written" do
    classroom = create_classroom
    student = create_student(classroom:)
    Orm::ClassroomStudent.where(student_id: student.id).update_all(joined_via: "link")

    assert_no_changes -> { [ classroom.reload.link_token, Orm::ClassroomStudent.find_by!(student_id: student.id).joined_via ] } do
      migrate(:up)
    end
  end
end

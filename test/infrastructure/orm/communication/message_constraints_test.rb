require "test_helper"

# ADR-0069 §4.1 (amends ADR-0045 §4): the three tables of the announcements and every rule the database holds by itself.
# Each CHECK refuses a faulty row; dismissals and targeted classrooms are unique per pair; the files hang on the message.
class Orm::MessageConstraintsTest < ActiveSupport::TestCase
  CHECKS = %w[messages_audience_values messages_status_values messages_illustration_values messages_title_present
              messages_body_present messages_published_at_when_live messages_ends_at_when_live messages_ends_at_window
              messages_withdrawn_iff_withdrawal messages_classrooms_need_school].freeze

  setup do
    @school = create_school
    @admin = create_school_admin(school: @school)
    @now = Time.current.change(usec: 0)
  end

  def connection = ActiveRecord::Base.connection

  def valid_attributes
    { author: @admin, title: "Devoirs communs", body: "Ils commencent lundi.", audience: "students", school: @school,
      status: "published", illustration: "info", published_at: @now, ends_at: @now + 30.days }
  end

  def write(**changes) = Orm::Message.transaction(requires_new: true) { Orm::Message.create!(valid_attributes.merge(changes)) }

  def assert_refused(error = ActiveRecord::CheckViolation, label = nil, **changes)
    assert_raises(error, label || changes.inspect) { write(**changes) }
  end

  test "the three tables exist, every check of messages is named after its rule" do
    assert(%w[messages message_classrooms message_dismissals].all? { connection.table_exists?(it) })
    assert_equal CHECKS.sort, connection.check_constraints("messages").map(&:name).sort
  end

  test "a valid published message is written, with an opaque public_id of 14 characters" do
    message = write

    assert_equal 14, message.public_id.size
    assert_equal message.public_id, message.to_param
    assert_equal [ @admin, @school ], [ message.author, message.school ]
  end

  test "audience, status and illustration stay in their closed lists" do
    assert_refused(audience: "teams")
    assert_refused(status: "deleted")
    assert_refused(illustration: "rocket")
    Entities::Communication::Message::ILLUSTRATIONS.each { |illustration| assert write(illustration:).persisted?, illustration }
  end

  test "AN-20 — a title of 61 characters, a text of 141 characters or a blank text is refused by the database" do
    assert_refused(ActiveRecord::ValueTooLong, title: "a" * 61)
    assert_refused(ActiveRecord::ValueTooLong, body: "é" * 141)
    assert_refused(body: "   ")
    assert_refused(title: "")
    assert_refused(ActiveRecord::NotNullViolation, body: nil)
    assert write(title: "a" * 60, body: "é" * 140).persisted?
  end

  test "a scheduled or published message has a publication date, a draft may have none" do
    assert_refused(status: "scheduled", published_at: nil, ends_at: nil)
    assert_refused(status: "published", published_at: nil, ends_at: nil)
    assert write(status: "draft", published_at: nil, ends_at: nil).persisted?
  end

  # ADR-0069, amendment of 2026-10-04: a draft archived before going live has no end date, and must stay archivable.
  test "a scheduled or published message has an end date; a draft, even archived, may have none" do
    assert_refused(ends_at: nil)
    assert_refused(status: "scheduled", ends_at: nil)
    assert write(status: "draft", published_at: nil, ends_at: nil).persisted?
    assert write(status: "archived", published_at: nil, ends_at: nil).persisted?
  end

  test "the end comes after the publication, at most 90 days later" do
    assert_refused(ends_at: @now)
    assert_refused(ends_at: @now - 1.day)
    assert_refused(ends_at: @now + 90.days + 1.second)
    assert write(ends_at: @now + 90.days).persisted?
    assert write(status: "draft", published_at: nil, ends_at: @now + 200.days).persisted?
  end

  test "a message is withdrawn exactly when it carries who withdrew it and when" do
    team = create_team_member(second_factor: false)

    assert_refused(status: "withdrawn")
    assert_refused(status: "withdrawn", withdrawn_at: @now)
    assert_refused(status: "withdrawn", withdrawn_by: team)
    assert_refused(withdrawn_at: @now, withdrawn_by: team)
    assert_equal team, write(status: "withdrawn", withdrawn_at: @now, withdrawn_by: team).withdrawn_by
  end

  test "a message for classrooms carries the school of its author" do
    teacher = create_teacher(school: @school)

    assert_refused(author: teacher, audience: "classrooms", school: nil)
    assert write(author: teacher, audience: "classrooms").persisted?
    assert write(audience: "all", school: nil).persisted?
  end

  test "authors, schools, moderators and classrooms can never be deleted under a message" do
    team = create_team_member(second_factor: false)
    classroom = create_classroom(school: @school)
    message = write(status: "withdrawn", withdrawn_at: @now, withdrawn_by: team)
    Orm::MessageClassroom.create!(message:, classroom:)

    [ [ "users", @admin.id ], [ "users", team.id ], [ "schools", @school.id ], [ "classrooms", classroom.id ] ].each do |table, id|
      assert_raises(ActiveRecord::InvalidForeignKey, table) do
        connection.transaction(requires_new: true) { connection.delete("DELETE FROM #{table} WHERE id = #{id}") }
      end
    end
  end

  test "a classroom is targeted once per message; deleting the message removes its targets and its dismissals" do
    message = write
    classroom = create_classroom(school: @school)
    student = create_student(classroom:)
    target = Orm::MessageClassroom.create!(message:, classroom:)
    dismissal = Orm::MessageDismissal.create!(message:, user: student, dismissed_at: @now)

    assert_equal [ target ], message.message_classrooms.to_a
    assert_equal [ message, classroom, student ], [ target.message, target.classroom, dismissal.user ]
    assert_raises(ActiveRecord::RecordNotUnique) do
      Orm::MessageClassroom.transaction(requires_new: true) { Orm::MessageClassroom.create!(message:, classroom:) }
    end
    assert_raises(ActiveRecord::RecordNotUnique) do
      Orm::MessageDismissal.transaction(requires_new: true) { Orm::MessageDismissal.create!(message:, user: student, dismissed_at: @now) }
    end
    assert_raises(ActiveRecord::NotNullViolation) do
      Orm::MessageDismissal.transaction(requires_new: true) { Orm::MessageDismissal.create!(message: write, user: student) }
    end

    connection.delete("DELETE FROM messages WHERE id = #{message.id}")

    assert_not Orm::MessageClassroom.exists?(target.id)
    assert_not Orm::MessageDismissal.exists?(dismissal.id)
  end

  test "the indexes of the reading, of « Mes annonces » and of the targets are in place" do
    indexes = ->(table) { connection.indexes(table).map { [ it.columns, it.unique ] } }

    assert_includes indexes.call("messages"), [ %w[status published_at], false ]
    assert_includes indexes.call("messages"), [ %w[school_id], false ]
    assert_includes indexes.call("messages"), [ %w[author_id created_at], false ]
    assert_includes indexes.call("messages"), [ %w[public_id], true ]
    assert_includes indexes.call("message_classrooms"), [ %w[message_id classroom_id], true ]
    assert_includes indexes.call("message_classrooms"), [ %w[classroom_id], false ]
    assert_includes indexes.call("message_dismissals"), [ %w[message_id user_id], true ]
  end

  test "a message holds one image and one audio file, outside any route of Active Storage" do
    message = write
    message.image.attach(io: StringIO.new("png"), filename: "a.png", content_type: "image/png", identify: false)
    message.audio.attach(io: StringIO.new("mp3"), filename: "a.mp3", content_type: "audio/mpeg", identify: false)

    assert_equal %w[a.png a.mp3], [ message.reload.image.filename.to_s, message.audio.filename.to_s ]
  end

  test "the factories write valid rows: a published message ends 30 days after its publication, a draft has no end" do
    teacher = create_teacher(school: @school)
    classrooms = [ create_classroom(school: @school), create_classroom(school: @school) ]
    published = create_message(author: @admin, school: @school)
    targeted = create_message(author: teacher, audience: "classrooms", classrooms:)
    draft = create_message(author: @admin, school: @school, status: "draft")
    withdrawn = create_message(author: teacher, audience: "classrooms", classrooms:, status: "withdrawn")
    dismissal = dismiss_message(message: published, user: create_student)

    assert_equal published.published_at + 30.days, published.ends_at
    assert_equal [ "Devoirs communs", "Ils commencent lundi.", "students", "info" ],
                 [ published.title, published.body, published.audience, published.illustration ]
    assert_equal [ @school, classrooms.map(&:id).sort ], [ targeted.school, targeted.message_classrooms.map(&:classroom_id).sort ]
    assert_nil draft.ends_at
    assert withdrawn.withdrawn_at && withdrawn.withdrawn_by
    assert_equal published, dismissal.message
    assert dismissal.dismissed_at
  end
end

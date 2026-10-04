require "test_helper"

module Repositories
  module Communication
    # ADR-0078 §6: the frozen port of the announcements. A message is read back with its targeted classrooms, written
    # with them in one transaction, and the scheduled ones are found when their time has come.
    class MessageRepositoryTest < ActiveSupport::TestCase
      Message = Entities::Communication::Message
      NOW = Time.utc(2026, 10, 3, 10)

      setup do
        @repository = MessageRepository.new
        @school = create_school
        @teacher = create_teacher(school: @school)
        @classrooms = Array.new(3) { create_classroom(school: @school) }
      end

      def draft(**changes)
        Message.new(author_id: @teacher.id, title: "Nouvelles fiches", body: "Elles sont en ligne.", audience: "classrooms",
                    school_id: @school.id, classroom_ids: [ @classrooms[1].id, @classrooms[0].id ], illustration: "sheets",
                    status: "published", published_at: NOW, ends_at: NOW + 30.days).with(**changes)
      end

      test "create writes the message and its targeted classrooms, and gives it back with its id and public id" do
        created = @repository.create(message: draft)

        assert_kind_of Integer, created.id
        assert_equal 14, created.public_id.size
        assert_equal created, @repository.find_by_public_id(public_id: created.public_id)
        assert_equal @classrooms.first(2).map(&:id).sort, created.classroom_ids
        assert_equal [ "Nouvelles fiches", "Elles sont en ligne.", "classrooms", @school.id, "sheets", "published", NOW, NOW + 30.days ],
                     created.deconstruct.values_at(3, 4, 5, 6, 8, 9, 10, 11)
      end

      test "create keeps a public id drawn by the domain, and a message by role has no classroom" do
        created = @repository.create(message: draft(public_id: "abcdefghijkmno", audience: "students", classroom_ids: []))

        assert_equal "abcdefghijkmno", created.public_id
        assert_empty @repository.find_by_public_id(public_id: "abcdefghijkmno").classroom_ids
        assert_not Orm::MessageClassroom.exists?(message_id: created.id)
      end

      test "a classroom listed twice is targeted once" do
        created = @repository.create(message: draft(classroom_ids: [ @classrooms[0].id, @classrooms[0].id ]))

        assert_equal [ @classrooms[0].id ], @repository.find_by_public_id(public_id: created.public_id).classroom_ids
      end

      test "a message whose classroom cannot be written is not written either" do
        assert_raises(ActiveRecord::InvalidForeignKey) { @repository.create(message: draft(classroom_ids: [ 0 ])) }

        assert_not Orm::Message.exists?(author_id: @teacher.id)
      end

      test "find_by_public_id reads every field of the row, and nil for an unknown message" do
        team = create_team_member(second_factor: false)
        row = create_message(author: @teacher, audience: "classrooms", classrooms: [ @classrooms[2] ], status: "withdrawn",
                             published_at: NOW, edited_at: NOW + 1.hour, withdrawn_by: team, withdrawn_at: NOW + 2.hours)

        message = @repository.find_by_public_id(public_id: row.public_id)

        assert_equal Message.new(id: row.id, public_id: row.public_id, author_id: @teacher.id, title: "Devoirs communs",
                                 body: "Ils commencent lundi.", audience: "classrooms", school_id: @school.id,
                                 classroom_ids: [ @classrooms[2].id ], illustration: "info", status: "withdrawn",
                                 published_at: NOW, ends_at: NOW + 30.days, edited_at: NOW + 1.hour,
                                 withdrawn_at: NOW + 2.hours, withdrawn_by_id: team.id), message
        assert_nil @repository.find_by_public_id(public_id: "inconnu")
      end

      test "update rewrites the message, replaces its targeted classrooms, never its author nor its public id" do
        created = @repository.create(message: draft)
        changed = created.with(title: "Fiches corrigées", body: "Version 2.", illustration: "homework", edited_at: NOW + 1.day,
                               classroom_ids: [ @classrooms[2].id ], author_id: create_teacher.id, public_id: "zzzzzzzzzzzzzz")

        updated = @repository.update(message: changed)

        stored = @repository.find_by_public_id(public_id: created.public_id)
        assert_equal stored, updated
        assert_equal [ "Fiches corrigées", "Version 2.", "homework", NOW + 1.day, [ @classrooms[2].id ] ],
                     [ stored.title, stored.body, stored.illustration, stored.edited_at, stored.classroom_ids ]
        assert_equal [ @teacher.id, created.public_id ], [ stored.author_id, stored.public_id ]
      end

      test "ADR-0078 §4.2 — update never rewrites a row frozen since it was read: nil, nothing written" do
        created = @repository.create(message: draft)
        team = create_team_member(second_factor: false)
        Orm::Message.where(id: created.id).update_all(status: "withdrawn", withdrawn_at: NOW, withdrawn_by_id: team.id)

        assert_nil @repository.update(message: created.with(title: "Remise en ligne", classroom_ids: [ @classrooms[2].id ]))
        assert_nil @repository.update(message: created.with(status: "archived"))
        stored = @repository.find_by_public_id(public_id: created.public_id)
        assert_equal [ "withdrawn", "Nouvelles fiches", created.classroom_ids ], [ stored.status, stored.title, stored.classroom_ids ]
      end

      test "update to an audience by role leaves no classroom behind" do
        created = @repository.create(message: draft)

        updated = @repository.update(message: created.with(audience: "students", classroom_ids: []))

        assert_empty updated.classroom_ids
        assert_not Orm::MessageClassroom.exists?(message_id: created.id)
      end

      test "clear_dismissals erases the dismissals of this message only, and counts them" do
        message = create_message(author: @teacher, audience: "classrooms", classrooms: [ @classrooms[0] ])
        other = create_message(author: @teacher, audience: "classrooms", classrooms: [ @classrooms[0] ])
        2.times { dismiss_message(message:, user: create_student(classroom: @classrooms[0])) }
        kept = dismiss_message(message: other, user: create_student(classroom: @classrooms[0]))

        assert_equal 2, @repository.clear_dismissals(message_id: message.id)

        assert_not Orm::MessageDismissal.exists?(message_id: message.id)
        assert Orm::MessageDismissal.exists?(kept.id)
        assert_equal 0, @repository.clear_dismissals(message_id: message.id)
      end

      test "AN-07 — due_for_publication gives the scheduled messages whose time has come, the oldest first" do
        later = create_message(author: @teacher, audience: "classrooms", classrooms: [ @classrooms[0] ], status: "scheduled",
                               published_at: NOW - 1.minute)
        sooner = create_message(author: @teacher, audience: "classrooms", classrooms: @classrooms.first(2), status: "scheduled",
                                published_at: NOW - 5.minutes)
        at_the_minute = create_message(author: @teacher, audience: "classrooms", classrooms: [ @classrooms[2] ],
                                       status: "scheduled", published_at: NOW)
        create_message(author: @teacher, audience: "classrooms", classrooms: [ @classrooms[0] ], status: "scheduled",
                       published_at: NOW + 8.hours)
        create_message(author: @teacher, audience: "classrooms", classrooms: [ @classrooms[0] ], published_at: NOW - 1.hour)
        create_message(author: @teacher, audience: "classrooms", classrooms: [ @classrooms[0] ], status: "draft")

        due = @repository.due_for_publication(now: NOW)

        assert_equal [ sooner, later, at_the_minute ].map(&:public_id), due.map(&:public_id)
        assert_equal [ @classrooms.first(2).map(&:id).sort, [ @classrooms[0].id ], [ @classrooms[2].id ] ], due.map(&:classroom_ids)
        assert(due.all? { it.status == "scheduled" })
        assert_empty @repository.due_for_publication(now: NOW - 1.hour)
      end

      test "author_role reads the role of the author's account" do
        authors = { team: create_team_member(second_factor: false), school_admin: create_school_admin(school: @school),
                    teacher: @teacher, student: create_student }

        authors.each do |role, author|
          assert_equal role, @repository.author_role(message: draft(author_id: author.id)), role
        end
      end
    end
  end
end

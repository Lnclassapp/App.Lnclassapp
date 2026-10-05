require "test_helper"

module Repositories
  module Communication
    # ADR-0078 §6: the frozen port of the announcements. A message is read back with its targeted classrooms, written
    # with them in one transaction, and the scheduled ones are found when their time has come. ADR-0081 §4 and §6: its
    # theme and its drawing of the team are written and read; live_of locks the author, then gives the live ones.
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

      test "AV-07 — create and update write the theme and the drawing of the team; find_by_public_id reads them back" do
        drawing = create_illustration(name: "Bus scolaire", created_by: create_team_member(second_factor: false))
        created = @repository.create(message: draft(theme: "mangue", illustration: nil, illustration_id: drawing.id))

        stored = @repository.find_by_public_id(public_id: created.public_id)
        assert_equal created, stored
        assert_equal [ "mangue", nil, drawing.id ], [ stored.theme, stored.illustration, stored.illustration_id ]

        updated = @repository.update(message: stored.with(theme: "nuit", illustration: "exam", illustration_id: nil))

        assert_equal [ "nuit", "exam", nil ], [ updated.theme, updated.illustration, updated.illustration_id ]
        assert_equal updated, @repository.find_by_public_id(public_id: created.public_id)
        assert_equal "ciel", @repository.create(message: draft).theme
      end

      def posted(**attributes)
        create_message(author: @teacher, audience: "classrooms", classrooms: [ @classrooms[0] ], **attributes)
      end

      def live_of(author = @teacher, now: NOW) = Orm::Message.transaction { @repository.live_of(author_id: author.id, now:) }

      test "AV-03 — live_of gives the author's live messages, the oldest first, then by id, with their classrooms" do
        newest = posted(published_at: NOW - 1.day)
        oldest = posted(published_at: NOW - 5.days, classrooms: @classrooms.first(2))
        tied = Array.new(2) { posted(published_at: NOW - 3.days) }
        create_message(author: create_teacher(school: @school), audience: "classrooms", classrooms: [ @classrooms[0] ],
                       published_at: NOW - 6.days)

        live = live_of

        assert_equal [ oldest, *tied.sort_by(&:id), newest ].map(&:public_id), live.map(&:public_id)
        assert(live.all?(Message))
        assert_equal [ @classrooms.first(2).map(&:id).sort, [ @classrooms[0].id ] ], live.first(2).map(&:classroom_ids)
        assert_equal @repository.find_by_public_id(public_id: newest.public_id), live.last
      end

      # A published message counts whatever its published_at: it was published when written, and a concurrent request
      # that read its clock before taking the lock must still count the message the other one has just published.
      test "AV-04 — only a published message not yet ended is live: ends_at > now; draft, scheduled, archived, withdrawn are not" do
        kept = [ posted(published_at: NOW - 2.days), posted(published_at: NOW) ]
        posted(status: "draft", published_at: nil)
        posted(status: "scheduled", published_at: NOW + 1.hour)
        posted(status: "archived", published_at: NOW - 1.day)
        posted(status: "withdrawn", published_at: NOW - 1.day)
        ended = posted(published_at: NOW - 31.days, ends_at: NOW - 1.day)
        ending = posted(published_at: NOW - 30.days, ends_at: NOW)
        just_published = posted(published_at: NOW + 1.minute)

        assert_equal (kept + [ just_published ]).map(&:public_id), live_of.map(&:public_id)
        assert_equal [ ended, ending, *kept, just_published ].map(&:public_id), live_of(now: NOW - 3.days).map(&:public_id)
        assert_empty live_of(create_teacher(school: @school))
      end

      def row_of(message) = Orm::Message.find(message.id).attributes.except("status", "updated_at")

      test "F2 — publish_scheduled writes only the status of a scheduled announcement whose time has come, and gives it back" do
        due = posted(status: "scheduled", published_at: NOW - 1.minute, classrooms: @classrooms.first(2), theme: "mangue")
        at_the_minute = posted(status: "scheduled", published_at: NOW)
        rows = [ due, at_the_minute ].map { row_of(it) }

        published = [ due, at_the_minute ].map { @repository.publish_scheduled(id: it.id, now: NOW) }

        assert_equal [ due, at_the_minute ].map { @repository.find_by_public_id(public_id: it.public_id) }, published
        assert_equal %w[published published], published.map(&:status)
        assert_equal @classrooms.first(2).map(&:id).sort, published.first.classroom_ids
        assert_equal rows, [ due, at_the_minute ].map { row_of(it) }, "rien d'autre que le statut n'est écrit"
      end

      test "F2 — publish_scheduled writes nothing to an announcement not yet due or no longer scheduled: nil" do
        later = posted(status: "scheduled", published_at: NOW + 1.minute)
        others = [ posted(status: "draft", published_at: nil), posted(published_at: NOW - 1.day),
                   posted(status: "archived", published_at: NOW - 1.day), posted(status: "withdrawn", published_at: NOW - 1.day) ]

        assert_equal [ nil ] * 5, [ later, *others ].map { @repository.publish_scheduled(id: it.id, now: NOW) }
        assert_nil @repository.publish_scheduled(id: 0, now: NOW)
        assert_equal %w[scheduled draft published archived withdrawn], [ later, *others ].map { it.reload.status }
      end

      test "author_role reads the role of the author's account" do
        authors = { team: create_team_member(second_factor: false), school_admin: create_school_admin(school: @school),
                    teacher: @teacher, student: create_student }

        authors.each do |role, author|
          assert_equal role, @repository.author_role(message: draft(author_id: author.id)), role
        end
      end
    end

    # ADR-0081 §4.1 and §6 (AV-05): live_of locks the author's row (SELECT … FOR NO KEY UPDATE) in the caller's transaction.
    # Outside any test transaction: each thread has its own connection, and sees what the other one committed.
    class MessageRepositoryLockTest < ActiveSupport::TestCase
      self.use_transactional_tests = false

      Message = Entities::Communication::Message
      NOW = Time.current.change(usec: 0)

      setup do
        @repository = MessageRepository.new
        @author = create_team_member(second_factor: false)
        @colleague = create_team_member(second_factor: false)
        @live = [ 5, 3, 1 ].map { create_message(author: @author, audience: "all", published_at: NOW - it.days) }
      end

      teardown do
        Orm::AuditEvent.where(actor_id: [ @author.id, @colleague.id ]).delete_all
        Orm::Message.where(author_id: [ @author.id, @colleague.id ]).delete_all
        Orm::User.where(id: [ @author.id, @colleague.id ]).delete_all
      end

      # From another connection: the row of the account, unless someone holds its lock (NOWAIT).
      def locked?(user)
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            Orm::User.transaction { Orm::User.where(id: user.id).lock("FOR UPDATE NOWAIT").pick(:id) }
            false
          rescue ActiveRecord::LockWaitTimeout
            true
          end
        end.value
      end

      def live_count = Orm::Message.where(author_id: @author.id, status: "published", published_at: ..NOW).where("ends_at > ?", NOW).count

      test "AV-05 — live_of holds the author's row until the caller's transaction ends, and only the author's" do
        held = Orm::Message.transaction do
          live = @repository.live_of(author_id: @author.id, now: NOW)
          [ live.map(&:public_id), locked?(@author), locked?(@colleague) ]
        end

        assert_equal [ @live.map(&:public_id), true, false ], held
        assert_not locked?(@author)
      end

      # Phase 5: FOR NO KEY UPDATE, not FOR UPDATE. A row that references the author by foreign key (the journal, a message)
      # takes FOR KEY SHARE on his account, which FOR UPDATE blocks for the whole publication, upload included.
      test "AV-05 — while live_of holds the author, another connection still journals an event of his within 300 ms" do
        journaled = Orm::Message.transaction do
          @repository.live_of(author_id: @author.id, now: NOW)
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              Orm::AuditEvent.transaction do
                Orm::AuditEvent.connection.execute("SET LOCAL lock_timeout = '300ms'")
                Repositories::Identity::AuditLogRepository.new.record(action: "message.published", actor_id: @author.id, at: NOW)
              end
            rescue ActiveRecord::LockWaitTimeout
              false
            end
          end.value
        end

        assert journaled, "l'événement attend la fin de la parution"
        assert_equal 1, Orm::AuditEvent.where(actor_id: @author.id).count
      end

      test "AV-05 — two publications of the same author at the same instant follow each other: 3 live, never 4" do
        gate = Queue.new
        threads = Array.new(2) do |index|
          Thread.new do
            gate.pop
            ActiveRecord::Base.connection_pool.with_connection do
              Repositories::Shared::Transaction.new.call do
                live = @repository.live_of(author_id: @author.id, now: NOW).tap { sleep 0.2 }
                live.first([ live.size - (Message::LIVE_CAP - 1), 0 ].max).each { @repository.update(message: it.with(status: "archived")) }
                @repository.create(message: Message.new(author_id: @author.id, title: "Annonce #{index}", body: "Le texte.",
                                                        audience: "all", illustration: "info", status: "published",
                                                        published_at: NOW, ends_at: NOW + Message::DURATION))
              end
            end
          end
        end
        2.times { gate << true }
        threads.each(&:join)

        assert_equal Message::LIVE_CAP, live_count
        assert_equal @live.first(2).map(&:id).sort, Orm::Message.where(author_id: @author.id, status: "archived").pluck(:id).sort
      end
    end
  end
end

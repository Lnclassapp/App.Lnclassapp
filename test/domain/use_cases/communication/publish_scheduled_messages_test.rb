require "test_helper"

module UseCases
  module Communication
    # AN-07, ADR-0045 §4 and ADR-0078 §4.5: the scheduled announcements whose time has come are published, each one
    # journaled with its author as actor; the others stay scheduled. Run by the job, without an actor (EXEMPT).
    # ADR-0081 §4.1 (annonces-v2): each publication by the job archives the oldest live ones of its author, under his
    # lock and in its transaction, until he has 3 live.
    class PublishScheduledMessagesTest < ActiveSupport::TestCase
      NOW = Time.zone.local(2026, 10, 1, 10, 5)
      Clock = Data.define(:now)

      # The list of due announcements, read before one of them changed (archived by its author meanwhile).
      class StaleMessages < SimpleDelegator
        def initialize(repository, stale) = super(repository).tap { @stale = stale }
        def due_for_publication(now:) = @stale
      end

      # Records, at each call of live_of, whether a transaction of the use case is open (AV-05).
      class SpyTransaction < Repositories::Shared::Transaction
        attr_reader :open

        def call(&)
          @open = true
          super
        ensure
          @open = false
        end
      end

      class WatchedMessages < SimpleDelegator
        attr_reader :live_of_calls

        def initialize(repository, transaction) = super(repository).tap { @transaction = transaction }
        def live_of(**) = __getobj__.live_of(**).tap { (@live_of_calls ||= []) << @transaction.open }
      end

      setup do
        @kamate = create_school_admin(last_name: "Kamaté")
        @morning = create_message(author: @kamate, title: "Réunion de 10 h", status: "scheduled", published_at: Time.zone.local(2026, 10, 1, 10))
        @evening = create_message(author: @kamate, title: "Réunion de 18 h", status: "scheduled", published_at: Time.zone.local(2026, 10, 1, 18))
      end

      def publish(messages = Repositories::Communication::MessageRepository.new, transaction: Repositories::Shared::Transaction.new)
        PublishScheduledMessages.new(messages:, audit_log: Repositories::Identity::AuditLogRepository.new, transaction:,
                                     clock: Clock.new(NOW)).call
      end

      # Three live announcements, published on September 25th, 27th and 29th (the oldest first).
      def three_live(author = @kamate)
        [ 25, 27, 29 ].map { create_message(author:, title: "Du #{it} septembre", published_at: Time.zone.local(2026, 9, it, 8)) }
      end

      def statuses(records) = records.map { it.reload.status }

      test "AN-07 — at 10:05, the announcement of 10:00 is published and journaled; the one of 18:00 stays scheduled" do
        result = publish

        assert_equal 1, result.value
        assert_equal [ "published", Time.zone.local(2026, 10, 1, 10) ], @morning.reload.values_at(:status, :published_at)
        assert_equal "scheduled", @evening.reload.status
        assert_equal [ [ @kamate.id, "Message", @morning.id, NOW ] ],
                     Orm::AuditEvent.where(action: "message.published").pluck(:actor_id, :subject_type, :subject_id, :created_at)
      end

      test "a second run publishes nothing more" do
        publish

        assert_equal 0, publish.value
        assert_equal 1, Orm::AuditEvent.where(action: "message.published").count
      end

      test "an announcement changed since the list was read is left as it is" do
        repository = Repositories::Communication::MessageRepository.new
        stale = repository.due_for_publication(now: NOW)
        @morning.update!(status: "archived")

        assert_equal 0, publish(StaleMessages.new(repository, stale)).value
        assert_equal "archived", @morning.reload.status
        assert_not Orm::AuditEvent.exists?(action: "message.published")
      end

      test "AV-04 — at its publication by the job, a scheduled announcement archives the oldest live one of its author" do
        live = three_live
        colleague = three_live(create_school_admin)

        assert_equal 1, publish.value
        assert_equal [ "archived", "published", "published" ], statuses(live)
        assert_equal %w[published published published], statuses(colleague)
        assert_equal "published", @morning.reload.status
        assert_equal [ [ @kamate.id, @morning.id ] ], Orm::AuditEvent.where(action: "message.published").pluck(:actor_id, :subject_id)
      end

      test "AV-04 — two scheduled announcements of the same author due together archive his two oldest live ones" do
        live = three_live
        @evening.update!(published_at: Time.zone.local(2026, 10, 1, 10, 1))

        assert_equal 2, publish.value
        assert_equal [ "archived", "archived", "published" ], statuses(live)
        assert_equal 3, Orm::Message.where(author: @kamate, status: "published").count
      end

      test "AV-04 — with 2 live, the publication by the job archives nothing" do
        live = [ 25, 27 ].map { create_message(author: @kamate, published_at: Time.zone.local(2026, 9, it, 8)) }

        publish

        assert_equal %w[published published], statuses(live)
      end

      test "AV-05 — the live announcements of the author are read inside the transaction of each publication" do
        three_live
        transaction = SpyTransaction.new
        messages = WatchedMessages.new(Repositories::Communication::MessageRepository.new, transaction)

        publish(messages, transaction:)

        assert_equal [ true ], messages.live_of_calls
      end
    end

    # ADR-0078 §4.2, ADR-0081 §4.1: archived by another request between its reading and its writing, the announcement
    # stays archived, and its publication writes nothing, not even the archiving of the oldest live one of its author.
    # Outside any test transaction: the other request commits on its own connection, as in production.
    class PublishScheduledMessagesRaceTest < ActiveSupport::TestCase
      self.use_transactional_tests = false

      # Reads the announcement, then lets another request archive it, committed, before the use case writes.
      class Racing < SimpleDelegator
        def initialize(repository, &race) = super(repository).tap { @race = race }

        def find_by_public_id(public_id:)
          __getobj__.find_by_public_id(public_id:).tap do
            Thread.new { ActiveRecord::Base.connection_pool.with_connection { @race.call } }.join
          end
        end
      end

      setup do
        @now = Time.current.change(usec: 0)
        @fatou = create_team_member(second_factor: false)
        @live = [ 5, 3, 1 ].map { create_message(author: @fatou, audience: "all", published_at: @now - it.days) }
        @due = create_message(author: @fatou, audience: "all", status: "scheduled", published_at: @now - 1.minute)
      end

      teardown do
        Orm::AuditEvent.where(actor_id: @fatou.id).delete_all
        Orm::Message.where(author_id: @fatou.id).delete_all
        Orm::User.where(id: @fatou.id).delete_all
      end

      test "AV-03 — archived between its reading and its writing: it stays archived, unjournaled, and no live one is archived" do
        racing = Racing.new(Repositories::Communication::MessageRepository.new) do
          Orm::Message.where(id: @due.id).update_all(status: "archived")
        end

        published = PublishScheduledMessages.new(messages: racing, audit_log: Repositories::Identity::AuditLogRepository.new,
                                                 transaction: Repositories::Shared::Transaction.new,
                                                 clock: Data.define(:now).new(@now)).call.value

        assert_equal 0, published
        assert_equal "archived", @due.reload.status
        assert_equal %w[published published published], @live.map { it.reload.status }
        assert_not Orm::AuditEvent.exists?(action: "message.published", actor_id: @fatou.id)
      end
    end
  end
end

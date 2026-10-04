require "test_helper"

module UseCases
  module Communication
    # AN-07, ADR-0045 §4 and ADR-0078 §4.5: the scheduled announcements whose time has come are published, each one
    # journaled with its author as actor; the others stay scheduled. Run by the job, without an actor (EXEMPT).
    class PublishScheduledMessagesTest < ActiveSupport::TestCase
      NOW = Time.zone.local(2026, 10, 1, 10, 5)
      Clock = Data.define(:now)

      # The list of due announcements, read before one of them changed (archived by its author meanwhile).
      class StaleMessages < SimpleDelegator
        def initialize(repository, stale) = super(repository).tap { @stale = stale }
        def due_for_publication(now:) = @stale
      end

      setup do
        @kamate = create_school_admin(last_name: "Kamaté")
        @morning = create_message(author: @kamate, title: "Réunion de 10 h", status: "scheduled", published_at: Time.zone.local(2026, 10, 1, 10))
        @evening = create_message(author: @kamate, title: "Réunion de 18 h", status: "scheduled", published_at: Time.zone.local(2026, 10, 1, 18))
      end

      def publish(messages = Repositories::Communication::MessageRepository.new)
        PublishScheduledMessages.new(messages:, audit_log: Repositories::Identity::AuditLogRepository.new,
                                     transaction: Repositories::Shared::Transaction.new, clock: Clock.new(NOW)).call
      end

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
    end
  end
end

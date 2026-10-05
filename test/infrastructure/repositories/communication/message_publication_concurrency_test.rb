require "test_helper"

module Repositories
  module Communication
    # Phase 5 of annonces-v2 (finding F1 of the security review, ADR-0081 §4.1). The same announcement published twice at
    # the same instant — two « Publier » of its author, or his « Publier » and the job — appears once: one announcement
    # archived by the cap, one « message.published » in the journal, no error; the second request is applied as a
    # modification of the live announcement. On two connections, outside any test transaction. The order of the two
    # requests is given by the author's lock (the first one keeps it until the second one waits on it), never by a sleep.
    class MessagePublicationConcurrencyTest < ActiveSupport::TestCase
      self.use_transactional_tests = false

      Input = Dtos::Communication::MessageInput

      # The first publication: says when it holds the author's lock (live_of), and keeps it until the test releases it.
      class Holding < MessageRepository
        def initialize(held:, release:)
          super()
          @held = held
          @release = release
        end

        def live_of(author_id:, now:)
          super.tap do
            @held << true
            @release.pop(timeout: 10)
          end
        end
      end

      setup do
        @now = Time.current.change(usec: 0)
        @fatou = create_team_member(second_factor: false)
        @live = [ 5, 3, 1 ].map { create_message(author: @fatou, audience: "all", title: "#{it} jours", published_at: @now - it.days) }
        @draft = create_message(author: @fatou, audience: "all", title: "Brouillon", status: "draft", published_at: nil)
        @scheduled = create_message(author: @fatou, audience: "all", title: "Programmée", status: "scheduled",
                                    published_at: @now - 1.minute)
      end

      teardown do
        Orm::AuditEvent.where(actor_id: @fatou.id).delete_all
        Orm::Message.where(author_id: @fatou.id).delete_all
        Orm::User.where(id: @fatou.id).delete_all
      end

      def clock = Data.define(:now).new(@now)

      # « Publier » from the form of the announcement, published now.
      def publish_by_author(message, messages, title: message.title)
        UseCases::Communication::UpdateMessage.new(
          messages:, attachments: AttachmentStore.new, schools: Repositories::School::SchoolRepository.new,
          classrooms: Repositories::Classroom::ClassroomRepository.new, teachings: Repositories::Classroom::TeachingRepository.new,
          audit_log: Repositories::Identity::AuditLogRepository.new, illustrations: IllustrationRepository.new,
          transaction: Repositories::Shared::Transaction.new, policy: Policies::Communication::ManageOwnPolicy.new,
          publish_policy: Policies::Communication::PublishPolicy.new, clock:
        ).call(actor: Repositories::Identity::UserRepository.new.actor_for(user_id: @fatou.id), public_id: message.public_id,
               dto: Input.new(title:, body: "Le texte.", illustration: "info", audience: "all", commit: "publish"))
      end

      def run_job(messages)
        UseCases::Communication::PublishScheduledMessages.new(messages:, audit_log: Repositories::Identity::AuditLogRepository.new,
                                                              transaction: Repositories::Shared::Transaction.new, clock:).call
      end

      def connected(&) = ActiveRecord::Base.connection_pool.with_connection(&)

      # first takes the author's lock and keeps it until second, on another connection, waits on it (or has ended); then
      # both end. Each one receives its repository. → [result of first, result of second]
      def one_after_the_other(first, second)
        held = Queue.new
        release = Queue.new
        backend = Queue.new
        threads = [ Thread.new { connected { first.call(Holding.new(held:, release:)) } } ]
        assert held.pop(timeout: 5), "la première parution ne prend pas le verrou de l'auteur"
        threads << Thread.new do
          connected do |connection|
            backend << connection.select_value("SELECT pg_backend_pid()")
            second.call(MessageRepository.new)
          end
        end
        wait_for_lock(threads.last, backend.pop(timeout: 5))
        release << true
        threads.map(&:value)
      ensure
        # Whatever happened, both requests end before the teardown erases their rows.
        release << true
        threads&.each { it.join(10) }
      end

      # Until the backend pid waits for a lock (a lock not granted in pg_locks), or its thread has ended; at most 5 s.
      def wait_for_lock(thread, pid)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        until !thread.alive? || waiting?(pid)
          if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
            flunk "la seconde parution n'attend pas le verrou de l'auteur"
          end
          sleep 0.01
        end
      end

      # Uncached: the query cache of the test would give the first answer again.
      def waiting?(pid)
        Orm::Message.uncached do
          Orm::Message.connection.select_value("SELECT EXISTS (SELECT 1 FROM pg_locks WHERE pid = #{Integer(pid)} AND NOT granted)")
        end
      end

      def statuses = @live.map { it.reload.status }
      def journaled(message) = Orm::AuditEvent.where(action: "message.published", subject_id: message.id).count

      test "AV-03 — F1: two « Publier » of the same draft at the same instant publish it once; the second one modifies it" do
        first, second = one_after_the_other(->(repository) { publish_by_author(@draft, repository) },
                                            ->(repository) { publish_by_author(@draft, repository, title: "Brouillon corrigé") })

        assert [ first, second ].all?(&:success?), [ first, second ].map(&:code).inspect
        assert_equal [ [ @live.first.public_id ], [] ], [ first, second ].map { it.value.archived.map(&:public_id) }
        assert_equal %w[archived published published], statuses
        assert_equal 1, journaled(@draft)
        assert_equal [ "published", "Brouillon corrigé", @now, @now + 30.days, @now ],
                     @draft.reload.values_at(:status, :title, :published_at, :ends_at, :edited_at)
      end

      test "AV-03 — F1: its author publishes a scheduled announcement while the job publishes it: it appears once" do
        mine, job = one_after_the_other(->(repository) { publish_by_author(@scheduled, repository) }, ->(repository) { run_job(repository) })

        assert mine.success?, mine.code.inspect
        assert_equal [ [ @live.first.public_id ], 0 ], [ mine.value.archived.map(&:public_id), job.value ]
        assert_equal %w[archived published published], statuses
        assert_equal 1, journaled(@scheduled)
        assert_equal [ "published", @now, nil ], @scheduled.reload.values_at(:status, :published_at, :edited_at)
      end

      test "AV-03 — F1: the job publishes a scheduled announcement while its author publishes it: it appears once" do
        job, mine = one_after_the_other(->(repository) { run_job(repository) }, ->(repository) { publish_by_author(@scheduled, repository) })

        assert mine.success?, mine.code.inspect
        assert_equal [ 1, [] ], [ job.value, mine.value.archived ]
        assert_equal %w[archived published published], statuses
        assert_equal 1, journaled(@scheduled)
        assert_equal [ "published", @now - 1.minute, @now ], @scheduled.reload.values_at(:status, :published_at, :edited_at)
      end
    end
  end
end

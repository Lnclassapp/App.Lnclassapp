require "test_helper"

module UseCases
  module Communication
    # AN-16, AN-17, ADR-0078 §4.2 and §4.5: the team or a direction withdraws an announcement it may moderate. It becomes
    # « withdrawn », dated and signed by its moderator, frozen for its author, and the journal records
    # « message.withdrawn » with the moderator for actor, in the same transaction. Anyone else learns nothing of it.
    class WithdrawMessageTest < ActiveSupport::TestCase
      NOW = Time.zone.local(2026, 10, 4, 9, 30)
      Clock = Data.define(:now)

      # A journal that fails: the withdrawal written before it must be undone with it.
      class BrokenAuditLog
        include Ports::Identity::AuditLogPort

        def record(**) = raise(ArgumentError, "journal indisponible")
      end

      # Reads the announcement, then lets another request change it before the use case writes (ADR-0078 §4.2).
      class Racing < SimpleDelegator
        def initialize(repository, &race) = super(repository).tap { @race = race }
        def find_by_public_id(public_id:) = __getobj__.find_by_public_id(public_id:).tap { @race.call }
      end

      setup do
        @lauriers = create_school(name: "Collège Les Lauriers")
        @bouake = create_school(name: "Lycée de Bouaké")
        @b3 = create_classroom(school: @lauriers, name: "3ème B")
        @kouassi = create_teacher(school: @lauriers, classrooms: [ @b3 ], gender: "male", last_name: "Kouassi")
        @kamate = create_school_admin(school: @lauriers, last_name: "Kamaté")
        @fatou = create_team_member(second_factor: false, first_name: "Fatou")
        @fiches = create_message(author: @kouassi, title: "Nouvelles fiches", audience: "classrooms", classrooms: [ @b3 ])
      end

      def actor(user) = Repositories::Identity::UserRepository.new.actor_for(user_id: user.id)

      def withdraw(user, message = @fiches, audit_log: Repositories::Identity::AuditLogRepository.new,
                   messages: Repositories::Communication::MessageRepository.new)
        WithdrawMessage.new(messages:, audit_log:,
                            transaction: Repositories::Shared::Transaction.new, policy: Policies::Communication::WithdrawPolicy.new,
                            clock: Clock.new(NOW))
                       .call(actor: user && actor(user), public_id: message.public_id)
      end

      def withdrawn_events = Orm::AuditEvent.where(action: "message.withdrawn")

      test "AN-16 — Fatou (team) withdraws « Nouvelles fiches »: withdrawn, dated, signed by her, and journaled with her as actor" do
        result = withdraw(@fatou)

        assert result.success?
        assert_equal [ "withdrawn", NOW, @fatou.id ], result.value.to_h.values_at(:status, :withdrawn_at, :withdrawn_by_id)
        assert_equal [ "withdrawn", NOW, @fatou.id ], @fiches.reload.values_at(:status, :withdrawn_at, :withdrawn_by_id)
        assert_equal [ [ @fatou.id, "Message", @fiches.id, { "author_id" => @kouassi.id }, NOW ] ],
                     withdrawn_events.pluck(:actor_id, :subject_type, :subject_id, :metadata, :created_at)
      end

      test "AN-16 — the withdrawal keeps the rest of the announcement: its text, its classes and its end date" do
        ends_at = @fiches.ends_at

        withdraw(@fatou)

        assert_equal [ "Nouvelles fiches", ends_at ], @fiches.reload.values_at(:title, :ends_at)
        assert_equal [ @b3.id ], Orm::MessageClassroom.where(message: @fiches).pluck(:classroom_id)
      end

      test "AN-16 — the team withdraws a scheduled announcement of a direction" do
        devoirs = create_message(author: @kamate, school: @lauriers, status: "scheduled", published_at: 2.days.from_now)

        assert withdraw(@fatou, devoirs).success?
        assert_equal "withdrawn", devoirs.reload.status
      end

      test "AN-17 — Mme Kamaté withdraws the announcement of a teacher of her school, journaled with her as actor" do
        assert withdraw(@kamate).success?
        assert_equal [ "withdrawn", @kamate.id ], @fiches.reload.values_at(:status, :withdrawn_by_id)
        assert_equal [ @kamate.id ], withdrawn_events.pluck(:actor_id)
      end

      test "AN-17 — the direction of Bouaké, M. Kouassi, a colleague and a student receive not_found; nothing is written" do
        refused = [ create_school_admin(school: @bouake), @kouassi, create_teacher(school: @lauriers), create_student(classroom: @b3), nil ]

        refused.each { assert_equal :not_found, withdraw(it).code, it&.role.inspect }
        assert_equal "published", @fiches.reload.status
        assert_empty withdrawn_events
      end

      test "AN-17 — the direction receives not_found for an announcement of the team and for one of M. Diallo" do
        rentree = create_message(author: @fatou, audience: "all")
        diallo = create_message(author: create_school_admin(school: @lauriers, last_name: "Diallo"), school: @lauriers)

        assert_equal [ :not_found, :not_found ], [ withdraw(@kamate, rentree).code, withdraw(@kamate, diallo).code ]
        assert_equal %w[published published], [ rentree.reload.status, diallo.reload.status ]
      end

      test "AN-16 — already withdrawn or archived, the announcement is frozen: conflict, nothing more is written" do
        archived = create_message(author: @kouassi, audience: "classrooms", classrooms: [ @b3 ], status: "archived")
        withdraw(@fatou)

        assert_equal :conflict, withdraw(@kamate).code
        assert_equal :conflict, withdraw(@fatou, archived).code
        assert_equal @fatou.id, @fiches.reload.withdrawn_by_id
        assert_equal "archived", archived.reload.status
        assert_equal 1, withdrawn_events.count
      end

      test "archived by its author while the team was withdrawing it: conflict, neither withdrawn nor journaled" do
        racing = Racing.new(Repositories::Communication::MessageRepository.new) do
          Orm::Message.where(id: @fiches.id).update_all(status: "archived")
        end

        assert_equal :conflict, withdraw(@fatou, messages: racing).code
        assert_equal [ "archived", nil ], @fiches.reload.values_at(:status, :withdrawn_by_id)
        assert_empty withdrawn_events
      end

      test "an unknown announcement is not_found" do
        assert_equal :not_found, withdraw(@fatou, Orm::Message.new(public_id: "inconnue")).code
      end

      test "the withdrawal and its journal are written together: a failing journal leaves the announcement published" do
        assert_raises(ArgumentError) { withdraw(@fatou, audit_log: BrokenAuditLog.new) }

        assert_equal [ "published", nil, nil ], @fiches.reload.values_at(:status, :withdrawn_at, :withdrawn_by_id)
      end
    end
  end
end

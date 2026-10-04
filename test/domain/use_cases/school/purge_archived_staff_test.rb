require "test_helper"

# ADR-0077 §4.3 (ID-22) : chaque compte direction archivé avant l'échéance est anonymisé (« Compte supprimé »), ses sessions
# fermées, son rattachement supprimé, et le journal porte « school_staff.deleted » ; une transaction par compte.
module UseCases
  module School
    class PurgeArchivedStaffTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 4, 4)
      AT = NOW - (30 * 86_400)
      Clock = Data.define(:now)

      class FakeStaffs
        include Ports::School::StaffRepositoryPort

        attr_reader :deleted, :asked_at

        def initialize(staffs)
          @staffs = staffs
          @deleted = []
        end

        def archived_before(at:)
          @asked_at = at
          @staffs.select { it.archived_at < at }
        end

        def delete(user_id:) = (@deleted << user_id) && true
      end

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        attr_reader :anonymized

        def initialize = @anonymized = []
        def anonymize(**args) = (@anonymized << args) && true
      end

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :closed

        def initialize = @closed = []
        def destroy_all_for(user_id:) = (@closed << user_id) && 1
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def initialize = @events = []
        def record(**event) = (@events << event) && true
      end

      def staff(user_id, archived_at)
        Entities::School::Staff.new(user_id:, user_public_id: "pub#{user_id}", school_id: 9, joined_via: "code",
                                    joined_at: archived_at - 86_400, archived_at:, archived_by_id: 5)
      end

      def purge(staffs:, actor: nil)
        @staffs = FakeStaffs.new(staffs)
        @users = FakeUsers.new
        @sessions = FakeSessions.new
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        PurgeArchivedStaff.new(staffs: @staffs, users: @users, sessions: @sessions, audit_log: @audit,
                               transaction: @transaction, policy: Policies::School::PurgeArchivedStaffPolicy.new,
                               clock: Clock.new(NOW))
                          .call(actor:, at: AT)
      end

      test "supprime chaque compte archivé avant l'échéance, une transaction par compte, et en rend le nombre" do
        result = purge(staffs: [ staff(11, AT - 60), staff(12, AT - 86_400), staff(13, AT + 86_400) ])

        assert result.success?
        assert_equal 2, result.value
        assert_equal AT, @staffs.asked_at
        assert_equal 2, @transaction.calls
        assert_equal [ { user_id: 11, first_name: "Compte", last_name: "supprimé", at: NOW },
                       { user_id: 12, first_name: "Compte", last_name: "supprimé", at: NOW } ], @users.anonymized
        assert_equal [ 11, 12 ], @sessions.closed
        assert_equal [ 11, 12 ], @staffs.deleted
        assert_equal({ action: "school_staff.deleted", actor_id: nil, at: NOW, subject_type: "User", subject_id: 11,
                       metadata: { school_id: 9 } }, @audit.events.first)
        assert_equal [ 11, 12 ], @audit.events.pluck(:subject_id)
      end

      test "sans compte échu, rien n'est écrit et le nombre est zéro" do
        result = purge(staffs: [ staff(13, AT + 60) ])

        assert_equal 0, result.value
        assert_empty @users.anonymized
        assert_empty @audit.events
        assert_equal 0, @transaction.calls
      end

      test "une personne connectée, même de l'équipe, ne lance pas la suppression" do
        team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")

        result = purge(staffs: [ staff(11, AT - 60) ], actor: team)

        assert_equal :forbidden, result.code
        assert_nil @staffs.asked_at
        assert_empty @users.anonymized
      end
    end
  end
end

require "test_helper"

# ADR-0077 §4.3 (ID-22) : chaque compte direction archivé avant l'échéance perd tout ce qu'efface AnonymizeUser pour un
# compte sans classe — photo, tentatives de connexion (numéro lu avant d'être effacé), nom et numéro, sessions, second
# facteur, codes de récupération —, puis son rattachement ; le journal porte « school_staff.deleted ». Une transaction
# par compte.
module UseCases
  module School
    class PurgeArchivedStaffTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 4, 4)
      AT = NOW - (30 * 86_400)
      Clock = Data.define(:now)

      # Chaque faux écrit dans un même journal : l'ordre des effacements se lit d'un bloc.
      class Journal
        attr_reader :calls

        def initialize = @calls = []
        def <<(call) = (@calls << call) && true
      end

      class FakeStaffs
        include Ports::School::StaffRepositoryPort

        attr_reader :asked_at

        def initialize(staffs, journal)
          @staffs = staffs
          @journal = journal
        end

        def archived_before(at:)
          @asked_at = at
          @staffs.select { it.archived_at < at }
        end

        def delete(user_id:) = @journal << [ :staff_deleted, user_id ]
      end

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def initialize(journal) = @journal = journal

        def find(id:)
          Entities::Identity::User.new(id:, public_id: "pub#{id}", last_name: "Traoré", first_name: "Aya",
                                       contact: format("07%08d", id), gender: "female", role: "school_admin",
                                       team_role: nil, anonymized_at: nil)
        end

        def anonymize(**args) = @journal << [ :anonymized, args ]
      end

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        def initialize(journal) = @journal = journal
        def destroy_all_for(user_id:) = @journal << [ :sessions_closed, user_id ]
      end

      class FakePhotos
        include Ports::Identity::ProfilePhotoStorePort

        def initialize(journal, failing: nil)
          @journal = journal
          @failing = failing
        end

        def remove(user_id:)
          raise IOError, "stockage indisponible" if user_id == @failing

          @journal << [ :photo_removed, user_id ]
        end
      end

      class FakeLoginAttempts
        include Ports::Identity::LoginAttemptRepositoryPort

        def initialize(journal) = @journal = journal
        def destroy_all_for(user_id:, contact:) = @journal << [ :login_attempts_erased, user_id, contact ]
      end

      class FakeSecondFactors
        include Ports::Identity::SecondFactorRepositoryPort

        def initialize(journal) = @journal = journal
        def reset(user_id:) = @journal << [ :second_factor_reset, user_id ]
      end

      class FakePinRecoveries
        include Ports::Identity::PinRecoveryRepositoryPort

        def initialize(journal) = @journal = journal
        def destroy_all_for(user_id:) = @journal << [ :pin_recoveries_erased, user_id ]
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        def initialize(journal) = @journal = journal
        def record(**event) = @journal << [ :audit, event ]
      end

      def staff(user_id, archived_at)
        Entities::School::Staff.new(user_id:, user_public_id: "pub#{user_id}", school_id: 9, joined_via: "code",
                                    joined_at: archived_at - 86_400, archived_at:, archived_by_id: 5)
      end

      def purge(staffs:, actor: nil, failing_photo: nil)
        @journal = Journal.new
        @staffs = FakeStaffs.new(staffs, @journal)
        @transaction = FakeTransaction.new
        PurgeArchivedStaff.new(staffs: @staffs, users: FakeUsers.new(@journal), sessions: FakeSessions.new(@journal),
                               photos: FakePhotos.new(@journal, failing: failing_photo), login_attempts: FakeLoginAttempts.new(@journal),
                               second_factors: FakeSecondFactors.new(@journal),
                               pin_recoveries: FakePinRecoveries.new(@journal), audit_log: FakeAudit.new(@journal),
                               transaction: @transaction, policy: Policies::School::PurgeArchivedStaffPolicy.new,
                               clock: Clock.new(NOW))
                          .call(actor:, at: AT)
      end

      def erasure_of(user_id)
        [ [ :photo_removed, user_id ],
          [ :login_attempts_erased, user_id, format("07%08d", user_id) ],
          [ :anonymized, { user_id:, first_name: "Compte", last_name: "supprimé", at: NOW } ],
          [ :sessions_closed, user_id ],
          [ :second_factor_reset, user_id ],
          [ :pin_recoveries_erased, user_id ],
          [ :staff_deleted, user_id ],
          [ :audit, { action: "school_staff.deleted", actor_id: nil, at: NOW, subject_type: "User", subject_id: user_id,
                      metadata: { school_id: 9 } } ] ]
      end

      test "efface chaque compte archivé avant l'échéance dans l'ordre d'AnonymizeUser, une transaction par compte" do
        result = purge(staffs: [ staff(11, AT - 60), staff(12, AT - 86_400), staff(13, AT + 86_400) ])

        assert result.success?
        assert_equal PurgeArchivedStaff::Purged.new(deleted: 2, failed: []), result.value
        assert_equal AT, @staffs.asked_at
        assert_equal 2, @transaction.calls
        assert_equal erasure_of(11) + erasure_of(12), @journal.calls
      end

      test "un compte en échec n'arrête pas les suivants : il est rendu dans failed, les autres sont supprimés" do
        result = purge(staffs: [ staff(11, AT - 60), staff(12, AT - 120) ], failing_photo: 11)

        assert_equal PurgeArchivedStaff::Purged.new(deleted: 1, failed: [ 11 ]), result.value
        assert_equal erasure_of(12), @journal.calls
      end

      test "sans compte échu, rien n'est écrit et le nombre est zéro" do
        result = purge(staffs: [ staff(13, AT + 60) ])

        assert_equal PurgeArchivedStaff::Purged.new(deleted: 0, failed: []), result.value
        assert_empty @journal.calls
        assert_equal 0, @transaction.calls
      end

      test "une personne connectée, même de l'équipe, ne lance pas la suppression" do
        team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")

        result = purge(staffs: [ staff(11, AT - 60) ], actor: team)

        assert_equal :forbidden, result.code
        assert_nil @staffs.asked_at
        assert_empty @journal.calls
      end
    end
  end
end

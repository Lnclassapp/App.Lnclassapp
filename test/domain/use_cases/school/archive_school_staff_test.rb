require "test_helper"

module UseCases
  module School
    # ID-12 to ID-16 (ADR-0077 §4.3): a direction account is removed: its attachment is archived (by whom, when), all its
    # sessions are closed and the removal is audited. A refusal writes nothing. The team (Lot C) uses the same use case.
    class ArchiveSchoolStaffTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 4, 9)
      DAY = 86_400
      Clock = Data.define(:now)
      SCHOOL_A = 31
      SCHOOL_B = 32

      class FakeStaff
        include Ports::School::StaffRepositoryPort

        attr_reader :rows

        def initialize(*rows) = @rows = rows

        def find_by_user_id(user_id:) = @rows.find { it.user_id == user_id }
        def find_by_public_id(public_id:) = @rows.find { it.user_public_id == public_id }

        def archive(user_id:, by_id:, at:)
          row = @rows.find { it.user_id == user_id && !it.archived? }
          return false unless row

          @rows[@rows.index(row)] = row.with(archived_at: at, archived_by_id: by_id)
          true
        end
      end

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        def initialize(*schools) = @schools = schools
        def find_by_id(id:) = @schools.find { it.id == id }
      end

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def initialize(*users) = @users = users
        def find(id:) = @users.find { it.id == id }
      end

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :sessions

        # sessions: [user_id]
        def initialize(sessions) = @sessions = sessions

        def destroy_all_for(user_id:)
          before = @sessions.size
          @sessions.delete(user_id)
          before - @sessions.size
        end
      end

      setup do
        @staff = FakeStaff.new(staff(1, days: 10), staff(2, public_id: "aya", days: 2), staff(3, public_id: "zadi", school_id: SCHOOL_B),
                               staff(4, public_id: "gone", archived_at: NOW - DAY))
        @schools = FakeSchools.new(Entities::School::School.new(id: SCHOOL_A, status: "active"),
                                   Entities::School::School.new(id: SCHOOL_B, status: "active"))
        @users = FakeUsers.new(user(1, "Kofi", "Yao"), user(2, "Aya", "Koné"), user(3, "Zadi", "Gnagbo"))
        @sessions = FakeSessions.new([ 2, 2, 1, 3 ])
        @audit = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @kofi = Entities::Identity::Actor.new(user_id: 1, role: :school_admin, school_id: SCHOOL_A)
      end

      def staff(user_id, public_id: "u#{user_id}", school_id: SCHOOL_A, days: 10, archived_at: nil, joined_via: "code")
        Entities::School::Staff.new(user_id:, user_public_id: public_id, school_id:, joined_via:, joined_at: NOW - (days * DAY),
                                    archived_at:, archived_by_id: archived_at && 99)
      end

      def user(id, first_name, last_name) = Entities::Identity::User.new(id:, public_id: "u#{id}", role: "school_admin", first_name:, last_name:)

      def archive(target_public_id: "aya", actor: @kofi)
        ArchiveSchoolStaff.new(staff: @staff, schools: @schools, users: @users, sessions: @sessions, audit_log: @audit,
                               policy: Policies::School::RemoveSchoolStaffPolicy.new, transaction: @transaction, clock: Clock.new(NOW))
                          .call(actor:, target_public_id:)
      end

      def row(user_id) = @staff.find_by_user_id(user_id:)

      def assert_nothing_written
        assert_not row(2).archived?
        assert_not row(3).archived?
        assert_equal [ 2, 2, 1, 3 ], @sessions.sessions
        assert_empty @audit.events
        assert_equal 0, @transaction.calls
      end

      test "ID-12 : Kofi retire Aya : archivée par Kofi, toutes ses sessions fermées, journal school_staff.archived" do
        result = archive

        assert result.success?
        assert_equal "Aya Koné", result.value.user.display_name
        assert_equal 2, result.value.staff.user_id
        assert_equal NOW, row(2).archived_at
        assert_equal 1, row(2).archived_by_id
        assert_equal [ 1, 3 ], @sessions.sessions
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "school_staff.archived", actor_id: 1, at: NOW, subject_type: "User", subject_id: 2,
                         metadata: { school_id: SCHOOL_A, joined_via: "code" } } ], @audit.events
      end

      test "ID-13 : un nouvel arrivant est refusé, rien n'est écrit" do
        aya = Entities::Identity::Actor.new(user_id: 2, role: :school_admin, school_id: SCHOOL_A)

        assert_equal :forbidden, archive(target_public_id: "u1", actor: aya).code
        assert_not row(1).archived?
        assert_nothing_written
      end

      test "ID-14 : soi-même est refusé" do
        assert_equal :forbidden, archive(target_public_id: "u1").code
        assert_not row(1).archived?
        assert_nothing_written
      end

      test "ID-15 : une direction d'un autre établissement est introuvable" do
        assert_equal :not_found, archive(target_public_id: "zadi").code
        assert_nothing_written
      end

      test "ID-16 : l'établissement inactif est refusé" do
        @schools = FakeSchools.new(Entities::School::School.new(id: SCHOOL_A, status: "inactive"))

        assert_equal :forbidden, archive.code
        assert_nothing_written
      end

      test "une cible inconnue ou déjà archivée est introuvable" do
        assert_equal :not_found, archive(target_public_id: "inconnu").code
        assert_equal :not_found, archive(target_public_id: "gone").code
        assert_nothing_written
      end

      test "deux onglets : la seconde archive ne trouve plus la cible active" do
        assert archive.success?
        assert_equal :not_found, archive.code
        assert_equal 1, @audit.events.size
      end

      test "archive perdue dans la course : :not_found, ni sessions fermées ni journal" do
        @staff.define_singleton_method(:archive) { |**| false }

        assert_equal :not_found, archive.code
        assert_equal [ 2, 2, 1, 3 ], @sessions.sessions
        assert_empty @audit.events
      end

      test "Lot C : l'équipe field retire une direction de tout établissement, même nouvelle" do
        field = Entities::Identity::Actor.new(user_id: 50, role: :team, team_role: "field")

        assert archive(target_public_id: "zadi", actor: field).success?
        assert_equal 50, row(3).archived_by_id
        assert_equal({ school_id: SCHOOL_B, joined_via: "code" }, @audit.events.sole[:metadata])
        assert archive(actor: field).success?
      end

      test "l'équipe content et le visiteur sont refusés" do
        content = Entities::Identity::Actor.new(user_id: 50, role: :team, team_role: "content")

        assert_equal :forbidden, archive(actor: content).code
        assert_equal :forbidden, archive(actor: nil).code
        assert_nothing_written
      end
    end
  end
end

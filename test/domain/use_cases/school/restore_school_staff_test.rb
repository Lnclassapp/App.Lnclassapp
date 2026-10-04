require "test_helper"

module UseCases
  module School
    # ID-19 and ID-20 (ADR-0077 §4.3): the team restores a removed direction before its deletion. An arrival by the code is
    # restored only under the cap of 3 active arrivals by the code (the repository counts under its lock); an invited
    # direction always is. The restoration is audited; a refusal writes nothing.
    class RestoreSchoolStaffTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 4, 9)
      DAY = 86_400
      Clock = Data.define(:now)
      SCHOOL_A = 31

      class FakeStaff
        include Ports::School::StaffRepositoryPort

        attr_reader :rows, :caps

        # by_code_active : the active arrivals by the code the repository counts, besides the rows.
        def initialize(*rows, by_code_active: 0)
          @rows = rows
          @by_code_active = by_code_active
          @caps = []
        end

        def find_by_public_id(public_id:) = @rows.find { it.user_public_id == public_id }

        def restore(user_id:, cap:)
          @caps << cap
          row = @rows.find { it.user_id == user_id }
          return :not_archived unless row&.archived?
          return :cap_reached if row.by_code? && @by_code_active >= cap

          @rows[@rows.index(row)] = row.with(archived_at: nil, archived_by_id: nil)
          :restored
        end
      end

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def initialize(*users) = @users = users
        def find(id:) = @users.find { it.id == id }
      end

      setup do
        @staff = staff_repository(by_code_active: 2)
        @users = FakeUsers.new(user(2, "Aya", "Koné"), user(3, "Awa", "Diallo"))
        @audit = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @admin = Entities::Identity::Actor.new(user_id: 50, role: :team, team_role: "admin")
      end

      def staff_repository(by_code_active:)
        FakeStaff.new(staff(1), staff(2, public_id: "aya", archived_at: NOW - DAY),
                      staff(3, public_id: "awa", archived_at: NOW - DAY, joined_via: "invitation"), by_code_active:)
      end

      def staff(user_id, public_id: "u#{user_id}", archived_at: nil, joined_via: "code")
        Entities::School::Staff.new(user_id:, user_public_id: public_id, school_id: SCHOOL_A, joined_via:, joined_at: NOW - (20 * DAY),
                                    archived_at:, archived_by_id: archived_at && 99)
      end

      def user(id, first_name, last_name) = Entities::Identity::User.new(id:, public_id: "u#{id}", role: "school_admin", first_name:, last_name:)

      def restore(target_public_id: "aya", actor: @admin)
        RestoreSchoolStaff.new(staff: @staff, users: @users, audit_log: @audit, policy: Policies::School::RestoreSchoolStaffPolicy.new,
                               transaction: @transaction, clock: Clock.new(NOW))
                          .call(actor:, target_public_id:)
      end

      def row(user_id) = @staff.rows.find { it.user_id == user_id }

      test "ID-19 : l'équipe admin restaure Aya (2 actives par le code) : active, journal school_staff.restored" do
        result = restore

        assert result.success?
        assert_equal 2, result.value.staff.user_id
        assert_equal "Aya Koné", result.value.user.display_name
        assert_not row(2).archived?
        assert_equal [ Entities::School::Staff::CODE_CAP ], @staff.caps
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "school_staff.restored", actor_id: 50, at: NOW, subject_type: "User", subject_id: 2,
                         metadata: { school_id: SCHOOL_A, joined_via: "code" } } ], @audit.events
      end

      test "ID-20 : 3 actives par le code : 409 cap_reached, Aya reste archivée ; une invitée se restaure" do
        @staff = staff_repository(by_code_active: 3)

        result = restore
        assert_equal :conflict, result.code
        assert_equal({ base: [ :cap_reached ] }, result.errors)
        assert row(2).archived?
        assert_empty @audit.events

        assert restore(target_public_id: "awa").success?
        assert_not row(3).archived?
        assert_equal({ school_id: SCHOOL_A, joined_via: "invitation" }, @audit.events.sole[:metadata])
      end

      test "l'équipe field restaure aussi" do
        field = Entities::Identity::Actor.new(user_id: 51, role: :team, team_role: "field")

        assert restore(actor: field).success?
        assert_equal 51, @audit.events.sole[:actor_id]
      end

      test "ID-21 : l'équipe content, la direction et le visiteur sont refusés, rien n'est écrit" do
        content = Entities::Identity::Actor.new(user_id: 52, role: :team, team_role: "content")
        direction = Entities::Identity::Actor.new(user_id: 1, role: :school_admin, school_id: SCHOOL_A)

        [ content, direction, nil ].each { assert_equal :forbidden, restore(actor: it).code }
        assert row(2).archived?
        assert_empty @staff.caps
        assert_empty @audit.events
      end

      test "une cible inconnue ou déjà active est introuvable, sans journal" do
        assert_equal :not_found, restore(target_public_id: "inconnu").code
        assert_equal :not_found, restore(target_public_id: "u1").code
        assert_empty @audit.events
      end

      test "deux onglets : la seconde restauration ne trouve plus la cible archivée" do
        assert restore.success?
        assert_equal :not_found, restore.code
        assert_equal 1, @audit.events.size
      end
    end
  end
end

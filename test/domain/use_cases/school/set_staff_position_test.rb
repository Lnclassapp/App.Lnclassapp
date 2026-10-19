require "test_helper"

module UseCases
  module School
    # ED-23, ED-24 (ADR-0092 §4.3): the team changes the position of an active direction; a second head of school is refused
    # (the repository checks it under the school's lock); the change is audited with the old and the new position; the same
    # position writes nothing. A direction never changes a position (ED-21, ED-22: the policy).
    class SetStaffPositionTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 16, 9)
      Clock = Data.define(:now)
      SCHOOL_A = 31

      class FakeStaff
        include Ports::School::StaffRepositoryPort

        attr_reader :rows, :writes

        # gone : la direction est retirée entre sa lecture et le verrou de l'établissement.
        def initialize(*rows, head_active: false, gone: false)
          @rows = rows
          @head_active = head_active
          @gone = gone
          @writes = []
        end

        def find_by_public_id(public_id:) = @rows.find { it.user_public_id == public_id }

        def set_position(user_id:, position:)
          row = @rows.find { it.user_id == user_id && !it.archived? }
          return :not_found if row.nil? || @gone
          return :unchanged if row.position == position
          return :head_taken if position == "head" && @head_active

          @writes << [ user_id, position ]
          @rows[@rows.index(row)] = row.with(position:)
          :set
        end
      end

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def find(id:) = Entities::Identity::User.new(id:, public_id: "u#{id}", role: "school_admin", first_name: "Awa", last_name: "Koné")
      end

      setup do
        @audit = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @field = Entities::Identity::Actor.new(user_id: 50, role: :team, team_role: "field")
      end

      def staff(user_id, position:, archived_at: nil)
        Entities::School::Staff.new(user_id:, user_public_id: "u#{user_id}", school_id: SCHOOL_A, joined_via: "code", joined_at: NOW,
                                    archived_at:, archived_by_id: archived_at && 99, position:)
      end

      def change(position:, target: "u2", actor: @field, rows: [ staff(2, position: "secretary") ], head_active: false, gone: false)
        @staff = FakeStaff.new(*rows, head_active:, gone:)
        SetStaffPosition.new(staff: @staff, users: FakeUsers.new, audit_log: @audit, policy: Policies::School::SetStaffPositionPolicy.new,
                             transaction: @transaction, clock: Clock.new(NOW))
                        .call(actor:, target_public_id: target, dto: Dtos::School::StaffPositionInput.new(position:))
      end

      test "ED-23: secretary becomes educator; audited with the old and the new position" do
        result = change(position: "educator")

        assert result.success?
        assert_equal [ "educator", "Awa Koné" ], [ result.value.position, result.value.user.display_name ]
        assert_equal [ [ 2, "educator" ] ], @staff.writes
        assert_equal [ { action: "school_staff.position_set", actor_id: 50, at: NOW, subject_type: "User", subject_id: 2,
                         metadata: { school_id: SCHOOL_A, from: "secretary", to: "educator" } } ], @audit.events
      end

      test "the same position succeeds without writing nor auditing" do
        assert change(position: "secretary").success?
        assert_empty @staff.writes
        assert_empty @audit.events
      end

      test "ED-24: head of school while another head is active: conflict on the position, nothing written" do
        result = change(position: "head", head_active: true)

        assert_equal :conflict, result.code
        assert_equal({ position: [ :head_taken ] }, result.errors)
        assert_empty @staff.writes
        assert_empty @audit.events
      end

      test "a missing or unknown position is invalid, before any read" do
        [ nil, "", "principal" ].each do |position|
          result = change(position:)

          assert_equal :invalid, result.code, position.inspect
          assert_equal [ :position ], result.errors.keys
        end
        assert_equal 0, @transaction.calls
      end

      test "an unknown or archived direction is not found" do
        assert_equal :not_found, change(position: "educator", target: "nobody").code
        assert_equal :not_found, change(position: "educator", rows: [ staff(2, position: "secretary", archived_at: NOW) ]).code
      end

      test "a direction removed between its reading and the lock is not found, nothing audited" do
        assert_equal :not_found, change(position: "educator", gone: true).code
        assert_empty @audit.events
      end

      test "ED-21, ED-22: a direction, the content team member and the visitor are refused, without reading" do
        [ Entities::Identity::Actor.new(user_id: 2, role: :school_admin, school_id: SCHOOL_A, staff_position: "head"),
          Entities::Identity::Actor.new(user_id: 51, role: :team, team_role: "content"), nil ].each do |actor|
          assert_equal :forbidden, change(position: "head", actor:).code
        end
        assert_empty @staff.writes
        assert_empty @audit.events
      end
    end
  end
end

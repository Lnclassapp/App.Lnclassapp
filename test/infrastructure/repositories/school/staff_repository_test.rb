require "test_helper"

module Repositories
  module School
    # ADR-0065 : un compte de direction est rattaché à un seul établissement. ADR-0077 : par invitation ou par le code,
    # dans un plafond ; archivé, restauré ou supprimé. ADR-0092 : avec sa fonction, un seul chef d'établissement actif.
    class StaffRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = StaffRepository.new
        @school = create_school
        @at = Time.utc(2026, 10, 4, 10)
      end

      test "attach writes the attachment of the direction account, dated, joined by invitation" do
        admin = create_user(role: "school_admin")
        inviter = create_team_member

        assert_equal :attached, @repository.attach(user_id: admin.id, school_id: @school.id, invited_by_id: inviter.id,
                                                   position: "educator", at: @at)
        assert_equal [ @school.id, inviter.id, @at, "invitation", "educator" ],
                     Orm::SchoolStaff.find_by!(user_id: admin.id)
                                     .then { [ it.school_id, it.invited_by_id, it.created_at, it.joined_via, it.position ] }
      end

      test "ED-14: attach refuses a head while another head is active, and writes nothing" do
        create_school_admin(school: @school, position: "head")
        admin = create_user(role: "school_admin")

        assert_equal :head_taken, @repository.attach(user_id: admin.id, school_id: @school.id, invited_by_id: nil, position: "head", at: @at)
        assert_not Orm::SchoolStaff.exists?(user_id: admin.id)
      end

      test "a second attachment of the same account is refused" do
        admin = create_school_admin

        assert_raises(ActiveRecord::RecordNotUnique) do
          @repository.attach(user_id: admin.id, school_id: create_school.id, invited_by_id: nil, position: "deputy", at: Time.current)
        end
      end

      test "attach_by_code attaches under the cap, by code, with no inviter" do
        admin = create_user(role: "school_admin")

        assert_equal :attached, @repository.attach_by_code(user_id: admin.id, school_id: @school.id, cap: 3, position: "secretary", at: @at)
        assert_equal [ "code", nil, @at, "secretary" ],
                     Orm::SchoolStaff.find_by!(user_id: admin.id).then { [ it.joined_via, it.invited_by_id, it.created_at, it.position ] }
      end

      test "ED-12: attach_by_code refuses a second active head; an archived head or another school's head does not count" do
        create_school_admin(school: @school, position: "head", archived_at: @at)
        create_school_admin(school: create_school, position: "head")
        first, second = Array.new(2) { create_user(role: "school_admin") }

        assert_equal :attached, @repository.attach_by_code(user_id: first.id, school_id: @school.id, cap: 3, position: "head", at: @at)
        assert_equal :head_taken, @repository.attach_by_code(user_id: second.id, school_id: @school.id, cap: 3, position: "head", at: @at)
        assert_not Orm::SchoolStaff.exists?(user_id: second.id)
      end

      test "head_taken? reads the active head of this school, except the given account" do
        head = create_school_admin(school: @school, position: "head")
        create_school_admin(school: @school, position: "secretary")

        assert @repository.head_taken?(school_id: @school.id)
        assert_not @repository.head_taken?(school_id: @school.id, except_user_id: head.id)
        assert_not @repository.head_taken?(school_id: create_school.id)
      end

      test "ED-23: set_position changes the position of an active direction; same position, :unchanged" do
        admin = create_school_admin(school: @school, position: "secretary")

        assert_equal [ :set, "secretary" ], @repository.set_position(user_id: admin.id, position: "educator")
        assert_equal "educator", Orm::SchoolStaff.find_by!(user_id: admin.id).position
        assert_equal :unchanged, @repository.set_position(user_id: admin.id, position: "educator")
      end

      test "ED-24: set_position refuses a second head; the head keeps head; archived or absent is :not_found" do
        head = create_school_admin(school: @school, position: "head")
        admin = create_school_admin(school: @school, position: "secretary")

        assert_equal :head_taken, @repository.set_position(user_id: admin.id, position: "head")
        assert_equal "secretary", Orm::SchoolStaff.find_by!(user_id: admin.id).position
        assert_equal :unchanged, @repository.set_position(user_id: head.id, position: "head")
        assert_equal :not_found, @repository.set_position(user_id: create_school_admin(school: @school, archived_at: @at).id, position: "head")
        assert_equal :not_found, @repository.set_position(user_id: create_teacher.id, position: "head")
      end

      test "ED-02: the partial index decides when the lock is bypassed: :head_taken, the caller's transaction intact" do
        create_school_admin(school: @school, position: "head")
        admin = create_user(role: "school_admin")
        repository = StaffRepository.new
        def repository.head_taken?(**) = false

        Orm::SchoolStaff.transaction do
          assert_equal :head_taken, repository.attach(user_id: admin.id, school_id: @school.id, invited_by_id: nil, position: "head", at: @at)
          assert Orm::SchoolStaff.where(school_id: @school.id).exists?, "the transaction still reads"
        end
      end

      test "ED-02: restore and set_position also fall back on the partial index: :head_taken, no exception, the transaction intact" do
        former = create_school_admin(school: @school, position: "head", archived_at: @at)
        admin = create_school_admin(school: @school, position: "secretary")
        create_school_admin(school: @school, position: "head")
        repository = StaffRepository.new
        def repository.head_taken?(**) = false

        Orm::SchoolStaff.transaction do
          assert_equal :head_taken, repository.restore(user_id: former.id, cap: 3)
          assert_equal :head_taken, repository.set_position(user_id: admin.id, position: "head")
          assert Orm::SchoolStaff.where(school_id: @school.id).exists?, "the transaction still reads"
        end
        assert_not_nil Orm::SchoolStaff.find_by!(user_id: former.id).archived_at
        assert_equal "secretary", Orm::SchoolStaff.find_by!(user_id: admin.id).position
      end

      test "ID-02, ID-03: the cap counts the active accounts by code only, of this school" do
        2.times { create_school_admin(school: @school, joined_via: "code") }
        create_school_admin(school: @school, joined_via: "code", archived_at: @at)
        4.times { create_school_admin(school: @school) }
        create_school_admin(school: create_school, joined_via: "code")
        third, fourth = Array.new(2) { create_user(role: "school_admin") }

        assert_equal :attached, @repository.attach_by_code(user_id: third.id, school_id: @school.id, cap: 3, position: "deputy", at: @at)
        assert_equal :cap_reached, @repository.attach_by_code(user_id: fourth.id, school_id: @school.id, cap: 3, position: "deputy", at: @at)
        assert_not Orm::SchoolStaff.exists?(user_id: fourth.id)
      end

      test "find_by_user_id and find_by_public_id read the attachment as an entity, archived or not" do
        author = create_team_member(second_factor: false)
        admin = create_school_admin(school: @school, joined_via: "code", joined_at: @at, archived_at: @at + 60, archived_by: author)
        expected = Entities::School::Staff.new(user_id: admin.id, user_public_id: admin.public_id, school_id: @school.id,
                                               joined_via: "code", joined_at: @at, archived_at: @at + 60, archived_by_id: author.id,
                                               position: "deputy")

        assert_equal expected, @repository.find_by_user_id(user_id: admin.id)
        assert_equal expected, @repository.find_by_public_id(public_id: admin.public_id)
        assert_nil @repository.find_by_user_id(user_id: create_teacher.id)
        assert_nil @repository.find_by_public_id(public_id: "absent")
      end

      test "archive dates the archiving and its author once; a second archive writes nothing" do
        admin = create_school_admin(school: @school)
        author = create_school_admin(school: @school)

        assert @repository.archive(user_id: admin.id, by_id: author.id, at: @at)
        assert_not @repository.archive(user_id: admin.id, by_id: create_team_member.id, at: @at + 60)
        assert_not @repository.archive(user_id: create_teacher.id, by_id: author.id, at: @at)
        assert_equal [ @at, author.id ], Orm::SchoolStaff.find_by!(user_id: admin.id).then { [ it.archived_at, it.archived_by_id ] }
      end

      test "restore brings back an archived account, refuses a code arrival over the cap, never an invited one" do
        by_code = create_school_admin(school: @school, joined_via: "code", archived_at: @at)
        invited = create_school_admin(school: @school, archived_at: @at)
        3.times { create_school_admin(school: @school, joined_via: "code") }

        assert_equal :cap_reached, @repository.restore(user_id: by_code.id, cap: 3)
        assert_equal :restored, @repository.restore(user_id: invited.id, cap: 3)
        assert_equal :not_archived, @repository.restore(user_id: invited.id, cap: 3)
        assert_equal :not_archived, @repository.restore(user_id: create_teacher.id, cap: 3)
        assert_nil Orm::SchoolStaff.find_by!(user_id: invited.id).archived_by_id
        assert_not_nil Orm::SchoolStaff.find_by!(user_id: by_code.id).archived_at
      end

      test "ED-25: the restoration of a former head is refused while another head is active" do
        former = create_school_admin(school: @school, position: "head", archived_at: @at)
        create_school_admin(school: @school, position: "head")

        assert_equal :head_taken, @repository.restore(user_id: former.id, cap: 3)
        assert_not_nil Orm::SchoolStaff.find_by!(user_id: former.id).archived_at
      end

      test "restore of a code arrival passes when a place is free" do
        by_code = create_school_admin(school: @school, joined_via: "code", archived_at: @at)

        assert_equal :restored, @repository.restore(user_id: by_code.id, cap: 3)
      end

      test "claim_for_purge is true only for an account still archived before the deadline" do
        due = create_school_admin(school: @school, archived_at: @at - 120)
        late = create_school_admin(school: @school, archived_at: @at)
        active = create_school_admin(school: @school)

        assert @repository.claim_for_purge(user_id: due.id, before: @at)
        assert_not @repository.claim_for_purge(user_id: late.id, before: @at)
        assert_not @repository.claim_for_purge(user_id: active.id, before: @at)
        assert_not @repository.claim_for_purge(user_id: create_teacher.id, before: @at)
      end

      test "restore of a deleted attachment is :not_archived" do
        gone = create_school_admin(school: @school, archived_at: @at)
        Orm::SchoolStaff.where(user_id: gone.id).delete_all

        assert_equal :not_archived, @repository.restore(user_id: gone.id, cap: 3)
      end

      test "archived_before lists the accounts archived strictly before, oldest first; delete removes the attachment" do
        old = create_school_admin(school: @school, archived_at: @at - 120)
        older = create_school_admin(school: @school, archived_at: @at - 240)
        create_school_admin(school: @school, archived_at: @at)
        create_school_admin(school: @school)

        assert_equal [ older.id, old.id ], @repository.archived_before(at: @at).map(&:user_id)
        assert @repository.delete(user_id: old.id)
        assert_not Orm::SchoolStaff.exists?(user_id: old.id)
      end
    end
  end
end

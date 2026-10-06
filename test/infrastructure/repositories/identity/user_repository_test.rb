require "test_helper"

module Repositories
  module Identity
    class UserRepositoryTest < ActiveSupport::TestCase
      setup { @repository = UserRepository.new }

      test "find, find_by_public_id and find_by_contact map the account without its PIN" do
        record = create_student(last_name: "Kouassi", first_name: "Jean Marc", gender: "male", contact: "0102030405")

        [ @repository.find(id: record.id), @repository.find_by_public_id(public_id: record.public_id),
          @repository.find_by_contact(contact: "0102030405") ].each do |user|
          assert_instance_of Entities::Identity::User, user
          assert_equal [ record.id, record.public_id, "Kouassi", "Jean Marc", "0102030405", "male", "student", nil ],
                       [ user.id, user.public_id, user.last_name, user.first_name, user.contact, user.gender, user.role, user.team_role ]
          assert_not user.respond_to?(:pin)
        end
      end

      test "an unknown account is nil" do
        assert_nil @repository.find(id: 0)
        assert_nil @repository.find_by_public_id(public_id: "inconnu")
        assert_nil @repository.find_by_contact(contact: "0100000000")
      end

      test "authenticate checks the PIN by bcrypt" do
        record = create_student(pin: "1357")

        assert_equal record.id, @repository.authenticate(contact: record.contact, pin: "1357").id
        assert_nil @repository.authenticate(contact: record.contact, pin: "2468")
        assert_nil @repository.authenticate(contact: "0199999999", pin: "1357")
      end

      test "update_pin replaces the PIN" do
        record = create_student(pin: "1357")

        assert @repository.update_pin(user_id: record.id, pin: "9753")
        assert @repository.authenticate(contact: record.contact, pin: "9753")
        assert_nil @repository.authenticate(contact: record.contact, pin: "1357")
      end

      test "actor_for gives the teacher their primary school" do
        school = create_school
        teacher = create_teacher(school:)

        actor = @repository.actor_for(user_id: teacher.id)

        assert_equal Entities::Identity::Actor.new(user_id: teacher.id, role: :teacher, school_id: school.id), actor
      end

      # ADR-0065 : une direction se connecte par PIN, et son acteur porte l'établissement de son rattachement.
      test "a school admin signs in by PIN and their actor carries their school" do
        school = create_school
        admin = create_school_admin(school:, pin: "1357")

        assert_equal admin.id, @repository.authenticate(contact: admin.contact, pin: "1357").id
        assert_equal Entities::Identity::Actor.new(user_id: admin.id, role: :school_admin, school_id: school.id),
                     @repository.actor_for(user_id: admin.id)
      end

      # ADR-0077 §4.2 : un compte direction archivé reçoit le refus d'un mauvais PIN ; une session survivante mène à l'attente.
      test "an archived school admin is not authenticated by their right PIN and their actor has no school" do
        admin = create_school_admin(pin: "1357", archived_at: 1.day.ago)

        assert_nil @repository.authenticate(contact: admin.contact, pin: "1357")
        assert_equal Entities::Identity::Actor.new(user_id: admin.id, role: :school_admin, school_id: nil),
                     @repository.actor_for(user_id: admin.id)
      end

      test "a restored school admin signs in again and finds their school" do
        school = create_school
        admin = create_school_admin(school:, pin: "1357", archived_at: 1.day.ago)
        admin.school_staff.update!(archived_at: nil, archived_by: nil)

        assert_equal admin.id, @repository.authenticate(contact: admin.contact, pin: "1357").id
        assert_equal school.id, @repository.actor_for(user_id: admin.id).school_id
      end

      test "actor_for gives a school admin without attachment no school" do
        admin = create_user(role: "school_admin")

        assert_nil @repository.actor_for(user_id: admin.id).school_id
      end

      test "actor_for carries the team role and no school" do
        member = create_team_member(team_role: "content")

        assert_equal Entities::Identity::Actor.new(user_id: member.id, role: :team, team_role: "content"),
                     @repository.actor_for(user_id: member.id)
      end

      test "update_name replaces the last and first names" do
        record = create_student(last_name: "Kouassi", first_name: "Aya")

        assert @repository.update_name(user_id: record.id, first_name: "Aya Marie", last_name: "Koné")
        assert_equal [ "Koné", "Aya Marie" ], @repository.find(id: record.id).then { [ it.last_name, it.first_name ] }
      end

      test "update_contact replaces the number the account signs in with" do
        record = create_student(contact: "0102030405", pin: "1357")

        assert @repository.update_contact(user_id: record.id, contact: "0711223344").success?
        assert_equal record.id, @repository.authenticate(contact: "0711223344", pin: "1357").id
        assert_nil @repository.find_by_contact(contact: "0102030405")
      end

      # The unique index refuses inside a savepoint: the transaction of the caller stays usable (reload below).
      test "update_contact is a conflict on a number held by another account, and writes nothing" do
        record = create_student(contact: "0102030405")
        create_student(contact: "0711223344")

        result = @repository.update_contact(user_id: record.id, contact: "0711223344")

        assert_equal [ :conflict, { contact: [ :taken ] } ], [ result.code, result.errors ]
        assert_equal "0102030405", record.reload.contact
      end

      # ADR-0036 §4: the number is freed, the PIN is a random secret nobody knows, the name says the account is gone.
      test "anonymize renames the account, frees its number, replaces its PIN and dates the anonymization" do
        record = create_student(contact: "0102030405", pin: "2468")
        at = Time.current.change(usec: 0)

        assert @repository.anonymize(user_id: record.id, first_name: "Compte", last_name: "supprimé", at:)

        record.reload
        assert_equal [ "Compte", "supprimé", nil, at ], [ record.first_name, record.last_name, record.contact, record.anonymized_at ]
        assert_not record.authenticate_pin("2468")
        assert_nil @repository.authenticate(contact: "0102030405", pin: "2468")
        assert create_student(contact: "0102030405").persisted?
      end
    end
  end
end

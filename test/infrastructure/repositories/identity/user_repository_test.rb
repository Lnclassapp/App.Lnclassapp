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
    end
  end
end

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

      test "actor_for gives a member of the direction the position and the school of their active membership (ADR-0066 §4.1)" do
        school = create_school
        admin = create_school_admin(school:, position: "censor")

        assert_equal Entities::Identity::Actor.new(user_id: admin.id, role: :school_admin, school_id: school.id, position: "censor"),
                     @repository.actor_for(user_id: admin.id)
      end

      test "actor_for: a member of the direction without active membership, or of an inactive school, has neither school nor position" do
        detached = create_school_admin
        Orm::SchoolStaff.where(user: detached).update_all(left_at: Time.current)
        inactive = create_school_admin(school: create_school(status: "inactive"))
        draft = create_school_admin(school: create_school(status: "draft"))
        never = create_user(role: "school_admin")

        [ detached, inactive, draft, never ].each do |admin|
          assert_equal Entities::Identity::Actor.new(user_id: admin.id, role: :school_admin), @repository.actor_for(user_id: admin.id)
        end
      end

      test "actor_for: a teacher's school is their primary school, whatever a staff row says" do
        teacher = create_teacher(school: nil)

        assert_equal Entities::Identity::Actor.new(user_id: teacher.id, role: :teacher), @repository.actor_for(user_id: teacher.id)
      end

      test "the student number is mapped; find_student_by_number is an exact match on living students (ADR-0065)" do
        student = create_student(student_number: "12345678A")
        create_student(student_number: "87654321B", anonymized_at: Time.current)

        found = @repository.find_student_by_number(student_number: "12345678A")

        assert_equal [ student.id, "12345678A" ], [ found.id, found.student_number ]
        assert_equal "12345678A", @repository.find(id: student.id).student_number
        assert_nil @repository.find_student_by_number(student_number: "87654321B")
        assert_nil @repository.find_student_by_number(student_number: "12345678")
        assert_nil @repository.find_student_by_number(student_number: "%")
        assert_nil @repository.find_student_by_number(student_number: "99999999Z")
      end

      test "update_student_number replaces the number of the student" do
        student = create_student(student_number: "12345678A")

        assert @repository.update_student_number(user_id: student.id, student_number: "12345678B").success?
        assert_equal "12345678B", student.reload.student_number
      end

      # The unique index refuses inside a savepoint: the transaction of the caller stays usable (reload below).
      test "update_student_number is a conflict on a number held by another account, and writes nothing" do
        student = create_student(student_number: "12345678A")
        create_student(student_number: "12345678B")

        result = @repository.update_student_number(user_id: student.id, student_number: "12345678B")

        assert_equal [ :conflict, { student_number: [ :taken ] } ], [ result.code, result.errors ]
        assert_equal "12345678A", student.reload.student_number
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

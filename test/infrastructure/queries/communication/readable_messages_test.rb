require "test_helper"

# ADR-0078 §4.3 and §7: the reading rule of the announcements, defined once in SQL (the list, the carousel and the files
# start from it) and tested one condition per test. A message is read when it is published, its publication has come and
# its end has not, and its audience covers the reader: by role (« all » or the role of the reader, nationwide or for the
# reader's school), or by classrooms (a student whose primary active classroom is targeted).
module Queries
  module Communication
    class ReadableMessagesTest < ActiveSupport::TestCase
      Reader = Entities::Communication::Reader

      setup do
        @rule = ReadableMessages.new
        @lauriers = create_school(name: "Collège Les Lauriers")
        @bouake = create_school(name: "Lycée de Bouaké")
        @troisieme_b = create_classroom(school: @lauriers, name: "3ème B")
        @troisieme_c = create_classroom(school: @lauriers, name: "3ème C")
        @troisieme_a = create_classroom(school: @lauriers, name: "3ème A")
        @awa = create_student(classroom: @troisieme_b, first_name: "Awa")
        @team = create_team_member(second_factor: false)
        @now = Time.current
      end

      def actor(user) = Repositories::Identity::UserRepository.new.actor_for(user_id: user.id)
      def reader(user) = @rule.reader_for(actor: actor(user))
      def titles(user, now: @now) = @rule.scope(reader: reader(user), now:).pluck(:title).sort
      def reads?(user, message, now: @now) = @rule.readable?(reader: reader(user), public_id: message.public_id, now:)

      # Readable by Awa unless the test changes one condition: published an hour ago, national, for students.
      def announce(title, author: @team, **) = create_message(author:, title:, **)

      test "a student is read through their primary active classroom and its school" do
        assert_equal Reader.new(user_id: @awa.id, role: :student, school_id: @lauriers.id, classroom_id: @troisieme_b.id),
                     reader(@awa)
      end

      test "a student without a primary active classroom has neither school nor classroom" do
        left = create_student(classroom: @troisieme_b)
        Orm::ClassroomStudent.where(student: left).update_all(left_at: Time.current)
        secondary = create_student
        Orm::ClassroomStudent.create!(joined_via: "standard", classroom: @troisieme_b, student: secondary, primary: false, joined_at: Time.current)
        archived = create_student(classroom: create_classroom(school: @lauriers, status: "archived"))

        [ create_student, left, secondary, archived ].each do |student|
          assert_equal Reader.new(user_id: student.id, role: :student, school_id: nil, classroom_id: nil), reader(student)
        end
      end

      test "a teacher is read through their primary school, a direction through its attachment, the team by itself" do
        teacher = create_teacher(school: @lauriers)
        direction = create_school_admin(school: @bouake)

        assert_equal Reader.new(user_id: teacher.id, role: :teacher, school_id: @lauriers.id, classroom_id: nil), reader(teacher)
        assert_equal Reader.new(user_id: direction.id, role: :school_admin, school_id: @bouake.id, classroom_id: nil), reader(direction)
        assert_equal Reader.new(user_id: @team.id, role: :team, school_id: nil, classroom_id: nil), reader(@team)
      end

      test "status: only a published message is read" do
        announce("Publiée")
        announce("Brouillon", status: "draft", ends_at: 1.day.from_now)
        announce("Programmée", status: "scheduled")
        announce("Archivée", status: "archived")
        announce("Retirée", status: "withdrawn")

        assert_equal [ "Publiée" ], titles(@awa)
      end

      test "publication: a message is read from its publication on, not before" do
        message = announce("Plus tard", published_at: @now + 1.hour)

        assert_not reads?(@awa, message)
        assert reads?(@awa, message, now: @now + 1.hour)
      end

      test "AN-08 — end: a message is no longer read from its end date on" do
        message = announce("Rentrée", published_at: @now - 30.days, ends_at: @now)

        assert reads?(@awa, message, now: @now - 1.second)
        assert_not reads?(@awa, message)
        assert_empty titles(@awa, now: @now + 1.day)
      end

      test "audience by role: a message for one role is read by that role alone" do
        teacher = create_teacher(school: @lauriers)
        direction = create_school_admin(school: @lauriers)
        announce("Élèves", audience: "students")
        announce("Enseignants", audience: "teachers")
        announce("Directions", audience: "school_admins")

        assert_equal [ "Élèves" ], titles(@awa)
        assert_equal [ "Enseignants" ], titles(teacher)
        assert_equal [ "Directions" ], titles(direction)
      end

      test "AN-01 — all: a national message for all is read by a student, a teacher and a direction of two schools" do
        message = announce("Rentrée numérique", audience: "all")
        readers = [ @awa, create_student(classroom: create_classroom(school: @bouake)), create_teacher(school: @lauriers),
                    create_teacher(school: @bouake), create_school_admin(school: @lauriers), create_school_admin(school: @bouake) ]

        readers.each { |user| assert reads?(user, message), user.role }
      end

      test "AN-02, AN-03 — school: a message for a school is read in that school only" do
        message = announce("Concours de maths", school: @lauriers)
        create_message(author: create_school_admin(school: @lauriers), title: "Devoirs communs", school: @lauriers)

        assert_equal [ "Concours de maths", "Devoirs communs" ], titles(@awa)
        assert_empty titles(create_student(classroom: create_classroom(school: @bouake)))
        assert_not reads?(create_student, message)
      end

      test "AN-02 — school: a message for the students of a school is read neither by its teachers nor by its direction" do
        message = announce("Concours de maths", school: @lauriers)

        assert_not reads?(create_teacher(school: @lauriers), message)
        assert_not reads?(create_school_admin(school: @lauriers), message)
      end

      test "school: a message for the teachers or the directions of a school is not read in another school" do
        teachers = announce("Conseil de classe", audience: "teachers", school: @lauriers)
        directions = announce("Réunion des directions", audience: "school_admins", school: @lauriers)

        assert reads?(create_teacher(school: @lauriers), teachers)
        assert_not reads?(create_teacher(school: @bouake), teachers)
        assert reads?(create_school_admin(school: @lauriers), directions)
        assert_not reads?(create_school_admin(school: @bouake), directions)
      end

      test "national: a message without school is read in every school, and by a reader without school" do
        message = announce("Rentrée numérique", school: nil)

        assert reads?(@awa, message)
        assert reads?(create_student(classroom: create_classroom(school: @bouake)), message)
        assert reads?(create_student, message)
      end

      test "AN-05 — classrooms: read by the students whose primary active classroom is targeted, by no one else" do
        kouassi = create_teacher(school: @lauriers, classrooms: [ @troisieme_b, @troisieme_c ])
        message = create_message(author: kouassi, title: "Nouvelles fiches", audience: "classrooms",
                                 classrooms: [ @troisieme_b, @troisieme_c ])

        assert reads?(@awa, message)
        assert reads?(create_student(classroom: @troisieme_c), message)
        assert_not reads?(create_student(classroom: @troisieme_a), message)
        [ kouassi, create_teacher(school: @lauriers, classrooms: [ @troisieme_b ]), create_school_admin(school: @lauriers) ].each do |adult|
          assert_not reads?(adult, message), adult.role
        end
      end

      test "classrooms: a secondary membership of a targeted classroom does not count" do
        message = create_message(author: create_teacher(school: @lauriers), audience: "classrooms", classrooms: [ @troisieme_b ])
        student = create_student(classroom: @troisieme_a)
        Orm::ClassroomStudent.create!(joined_via: "standard", classroom: @troisieme_b, student:, primary: false, joined_at: Time.current)

        assert_not reads?(student, message)
      end

      test "AN-21 — a student without an active classroom reads the national messages for all or for students alone" do
        teacher = create_teacher(school: @lauriers)
        announce("Tous", audience: "all")
        announce("Élèves")
        announce("Enseignants", audience: "teachers")
        announce("Collège", school: @lauriers)
        create_message(author: teacher, title: "Fiches", audience: "classrooms", classrooms: [ @troisieme_b ])

        assert_equal [ "Tous", "Élèves" ].sort, titles(create_student)
      end

      test "AN-21 — a student moved from 3ème B to 4ème A no longer reads 3ème B, and reads 4ème A" do
        quatrieme_a = create_classroom(school: @lauriers, name: "4ème A")
        teacher = create_teacher(school: @lauriers)
        create_message(author: teacher, title: "Nouvelles fiches", audience: "classrooms", classrooms: [ @troisieme_b ])
        create_message(author: teacher, title: "Sortie", audience: "classrooms", classrooms: [ quatrieme_a ])
        Orm::ClassroomStudent.where(student: @awa).update_all(left_at: Time.current)
        Orm::ClassroomStudent.create!(joined_via: "standard", classroom: quatrieme_a, student: @awa, primary: true, joined_at: Time.current)

        assert_equal [ "Sortie" ], titles(@awa)
      end

      test "the team is the audience of no message: it reads by its role (files, moderation), not by this rule" do
        message = announce("Rentrée numérique", audience: "all")

        assert_empty titles(@team)
        assert_not reads?(@team, message)
      end

      test "readable? answers for one message by its public_id; an unknown public_id is not read" do
        message = announce("Rentrée")
        other = announce("Autre", audience: "teachers")

        assert reads?(@awa, message)
        assert_not reads?(@awa, other)
        assert_not @rule.readable?(reader: reader(@awa), public_id: "inconnu", now: @now)
      end
    end
  end
end

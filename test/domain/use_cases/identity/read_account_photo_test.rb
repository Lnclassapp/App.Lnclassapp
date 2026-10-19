require "test_helper"

# PH-05, ADR-0060: a photo is read under the rule for reading an account (ReadUserPolicy): oneself, the team, a teacher
# for a student present in a classroom they teach (active or archived, like the class list). Never another student.
module UseCases
  module Identity
    class ReadAccountPhotoTest < ActiveSupport::TestCase
      STUDENT = Entities::Identity::User.new(id: 20, public_id: "stu20", role: "student", first_name: "Awa", last_name: "Koné")
      TEACHER_USER = Entities::Identity::User.new(id: 5, public_id: "tea5", role: "teacher", first_name: "Yao", last_name: "Brou")
      PHOTO = Ports::Identity::ProfilePhotoStorePort::StoredPhoto.new(content_type: "image/webp", data: "RIFF")

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def find_by_public_id(public_id:) = [ STUDENT, TEACHER_USER ].find { it.public_id == public_id }
      end

      class FakeMemberships
        include Ports::Classroom::MembershipRepositoryPort

        def initialize(membership) = @membership = membership
        def primary_for(student_id:) = (@membership if student_id == STUDENT.id)
      end

      # La classe 3 est dans l'établissement 1, la classe 9 dans l'établissement 2.
      class FakeTeachings
        include Ports::Classroom::TeachingRepositoryPort

        SCHOOL_OF = { 3 => 1, 9 => 2 }.freeze

        def classroom_ids_for(teacher_id:, school_id: nil)
          { 5 => [ 3, 9 ], 6 => [ 9 ] }.fetch(teacher_id, []).select { school_id.nil? || SCHOOL_OF[it] == school_id }
        end
      end

      def membership(status: "active", classroom_id: 3)
        Entities::Classroom::Membership.new(classroom_id:, student_id: STUDENT.id, primary: true, joined_at: Time.utc(2026, 9, 1),
                                            left_at: nil, classroom_status: status)
      end

      def read(actor, public_id: STUDENT.public_id, membership: self.membership, photos: { STUDENT.id => PHOTO, TEACHER_USER.id => PHOTO })
        ReadAccountPhoto.new(users: FakeUsers.new, memberships: FakeMemberships.new(membership), teachings: FakeTeachings.new,
                             photos: FakeProfilePhotoStore.new(photos), policy: Policies::Identity::ReadUserPolicy.new)
                        .call(actor:, target_public_id: public_id)
      end

      # Un enseignant est dans son établissement courant : le 1 par défaut.
      def actor(user_id, role, school_id: (1 if role == :teacher)) = Entities::Identity::Actor.new(user_id:, role:, school_id:)

      test "the student, the team and the teacher of the student's classroom read the photo" do
        [ actor(20, :student), actor(7, :team), actor(5, :teacher) ].each do |reader|
          result = read(reader)

          assert result.success?, reader.inspect
          assert_equal PHOTO, result.value
        end
      end

      test "the teacher still reads it when the classroom is archived: the class list still shows the student" do
        assert read(actor(5, :teacher), membership: membership(status: "archived")).success?
      end

      test "another student, a teacher of another classroom, a teacher for a student without a classroom: forbidden" do
        assert_equal :forbidden, read(actor(21, :student)).code
        assert_equal :forbidden, read(actor(6, :teacher)).code
        assert_equal :forbidden, read(actor(5, :teacher), membership: nil).code
        assert_equal :forbidden, read(actor(6, :teacher), public_id: TEACHER_USER.public_id).code
        assert_equal :forbidden, read(nil).code
      end

      # Revue de la PR #250, constat 3 (ADR-0094 §10) : l'enseignant de A et de B, passé dans A, ne lit pas la photo de
      # l'élève de sa classe de B ; passé dans B, si.
      test "a teacher in A is refused the photo of a student of his classroom of B; in B, he reads it" do
        in_b = membership(classroom_id: 9)

        assert_equal :forbidden, read(actor(5, :teacher), membership: in_b).code
        assert read(actor(5, :teacher, school_id: 2), membership: in_b).success?
      end

      test "an unknown account, or an account without a photo: not found" do
        assert_equal :not_found, read(actor(7, :team), public_id: "nobody").code
        assert_equal :not_found, read(actor(20, :student), photos: {}).code
      end
    end
  end
end

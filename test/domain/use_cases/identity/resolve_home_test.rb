require "test_helper"

module UseCases
  module Identity
    class ResolveHomeTest < ActiveSupport::TestCase
      class FakeMemberships
        include Ports::Classroom::MembershipRepositoryPort

        def initialize(membership) = @membership = membership
        def primary_for(student_id:) = @membership
      end

      class FakeProfiles
        include Ports::Identity::TeacherProfileRepositoryPort

        def initialize(profile) = @profile = profile
        def find_by_user_id(user_id:) = @profile
      end

      def resolve(actor, membership: nil, profile: nil)
        ResolveHome.new(memberships: FakeMemberships.new(membership), teacher_profiles: FakeProfiles.new(profile)).call(actor:)
      end

      def actor(role, school_id: nil) = Entities::Identity::Actor.new(user_id: 1, role:, school_id:)

      test "l'anonyme n'a pas d'accueil" do
        assert_equal :forbidden, resolve(nil).code
      end

      test "un élève dans une classe active va à son accueil" do
        membership = Entities::Classroom::Membership.new(classroom_id: 2, student_id: 1, primary: true,
                                                         joined_at: Time.utc(2026, 9, 1), left_at: nil, classroom_status: "active")

        assert_equal :student_home, resolve(actor(:student), membership:).value
        assert_equal :pending_account, resolve(actor(:student)).value
      end

      test "l'enseignant suit son onboarding persisté" do
        done = Entities::Identity::TeacherProfile.new(user_id: 1, material_id: 3, onboarding_completed_at: Time.utc(2026, 9, 2))
        pending = done.with(onboarding_completed_at: nil)

        assert_equal :teacher_home, resolve(actor(:teacher, school_id: 4), profile: done).value
        assert_equal :teacher_classrooms, resolve(actor(:teacher, school_id: 4), profile: pending).value
        assert_equal :teacher_classrooms, resolve(actor(:teacher, school_id: 4)).value
      end

      test "l'équipe va à son accueil" do
        assert_equal :team_home, resolve(actor(:team)).value
      end
    end
  end
end

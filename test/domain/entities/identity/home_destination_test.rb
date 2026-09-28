require "test_helper"

module Entities
  module Identity
    class HomeDestinationTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25)

      def actor(role) = Actor.new(user_id: 1, role:)

      def membership(left_at: nil, classroom_status: "active")
        Entities::Classroom::Membership.new(classroom_id: 3, student_id: 1, primary: true, joined_at: NOW,
                                            left_at:, classroom_status:)
      end

      def destination(actor, membership: nil, school_id: nil, onboarded: false)
        HomeDestination.for(actor:, primary_membership: membership, primary_school_id: school_id, onboarded:)
      end

      test "un élève avec une classe principale active va à son accueil" do
        assert_equal :student_home, destination(actor(:student), membership:)
      end

      test "un élève sans classe, sorti ou dont la classe est archivée attend" do
        assert_equal :pending_account, destination(actor(:student))
        assert_equal :pending_account, destination(actor(:student), membership: membership(left_at: NOW))
        assert_equal :pending_account, destination(actor(:student), membership: membership(classroom_status: "archived"))
      end

      test "un enseignant sans école attend, sinon onboarding puis accueil" do
        assert_equal :pending_account, destination(actor(:teacher), onboarded: true)
        assert_equal :teacher_classrooms, destination(actor(:teacher), school_id: 4)
        assert_equal :teacher_home, destination(actor(:teacher), school_id: 4, onboarded: true)
      end

      test "l'équipe va à son accueil" do
        assert_equal :team_home, destination(actor(:team))
      end

      # ADR-0066 §4.1 : l'acteur de la direction porte l'établissement de son rattachement actif, nil sans.
      test "la direction rattachée va à son accueil, sans établissement elle attend" do
        attached = Actor.new(user_id: 1, role: :school_admin, school_id: 4, position: "censor")

        assert_equal :school_admin_home, destination(attached)
        assert_equal :pending_account, destination(actor(:school_admin))
        assert_includes HomeDestination::ALL, :school_admin_home
      end
    end
  end
end

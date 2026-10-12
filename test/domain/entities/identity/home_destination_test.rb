require "test_helper"

module Entities
  module Identity
    class HomeDestinationTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25)

      def actor(role, school_id: nil) = Actor.new(user_id: 1, role:, school_id:)

      def membership(left_at: nil, classroom_status: "active")
        Entities::Classroom::Membership.new(classroom_id: 3, student_id: 1, primary: true, joined_at: NOW,
                                            left_at:, classroom_status:)
      end

      def destination(actor, school_id: nil, onboarded: false)
        HomeDestination.for(actor:, primary_school_id: school_id, onboarded:)
      end

      test "un élève avec une classe principale active va à son accueil" do
        assert_equal :student_home, destination(actor(:student))
        assert HomeDestination.enrolled?(membership)
      end

      # IL-14, ADR-0085 §4.3 : l'élève sans classe active arrive sur son accueil, qui propose « Choisis ta classe » ; plus
      # jamais sur l'écran d'attente, qui l'envoyait vers le code de classe.
      test "IL-14 : un élève sans classe, sorti ou dont la classe est archivée va aussi à son accueil, sans classe" do
        [ nil, membership(left_at: NOW), membership(classroom_status: "archived") ].each do |current|
          assert_equal :student_home, destination(actor(:student))
          assert_equal false, HomeDestination.enrolled?(current)
        end
      end

      test "un enseignant sans école attend, sinon onboarding puis accueil" do
        assert_equal :pending_account, destination(actor(:teacher), onboarded: true)
        assert_equal :teacher_classrooms, destination(actor(:teacher), school_id: 4)
        assert_equal :teacher_home, destination(actor(:teacher), school_id: 4, onboarded: true)
      end

      test "l'équipe va à son accueil" do
        assert_equal :team_home, destination(actor(:team))
      end

      # DS-05 (ADR-0065, UDR-0052) : « Travail des élèves » est l'accueil de la direction rattachée ; sans établissement,
      # ReadOwnSchoolPolicy lui refuserait cette page : elle attend, sans boucle de redirection.
      test "une direction rattachée arrive sur « Travail des élèves », une direction sans établissement attend" do
        assert_equal :school_admin_classrooms, destination(actor(:school_admin, school_id: 4))
        assert_equal :pending_account, destination(actor(:school_admin))
        assert_includes HomeDestination::ALL, :school_admin_classrooms
      end
    end
  end
end

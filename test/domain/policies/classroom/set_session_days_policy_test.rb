require "test_helper"

module Policies
  module Classroom
    # ADR-0072 §4.2 : l'enseignant de la classe écrit ses propres jours, sur une classe active ; personne d'autre.
    class SetSessionDaysPolicyTest < ActiveSupport::TestCase
      def call(actor, status: "active")
        SetSessionDaysPolicy.new.call(actor:, classroom: Entities::Classroom::Classroom.new(teacher_ids: [ 1 ], status:))
      end

      def actor(role, user_id: 1) = Entities::Identity::Actor.new(user_id:, role:)

      test "l'enseignant de la classe renseigne ses jours" do
        assert call(actor(:teacher)).success?
      end

      test "refuse l'équipe, qui n'a pas de jours, un autre enseignant, un élève, la direction et le visiteur" do
        [ actor(:team), actor(:teacher, user_id: 2), actor(:student), actor(:school_admin), nil ].each do |someone|
          assert_equal :forbidden, call(someone).code, someone.inspect
        end
      end

      test "refuse une classe archivée, même à son enseignant" do
        result = call(actor(:teacher), status: "archived")

        assert_equal :forbidden, result.code
        assert_equal [ :classroom_archived ], result.errors[:base]
      end
    end
  end
end

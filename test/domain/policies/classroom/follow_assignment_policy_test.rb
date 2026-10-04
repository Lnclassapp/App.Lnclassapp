require "test_helper"

module Policies
  module Classroom
    # ADR-0072 §4.5 : la liste nominative des retardataires, à l'enseignant de la classe et à l'équipe seulement.
    class FollowAssignmentPolicyTest < ActiveSupport::TestCase
      def call(actor, status: "active")
        FollowAssignmentPolicy.new.call(actor:, classroom: Entities::Classroom::Classroom.new(teacher_ids: [ 1 ], status:))
      end

      def actor(role, user_id: 1) = Entities::Identity::Actor.new(user_id:, role:)

      test "l'enseignant de la classe et l'équipe suivent l'exercice, classe active ou archivée" do
        %w[active archived].each do |status|
          assert call(actor(:teacher), status:).success?, status
          assert call(actor(:team, user_id: 9), status:).success?, status
        end
      end

      test "refuse un élève de la classe, un autre enseignant, la direction et le visiteur" do
        [ actor(:student), actor(:teacher, user_id: 2), actor(:school_admin), nil ].each do |someone|
          assert_equal :forbidden, call(someone).code, someone.inspect
        end
      end
    end
  end
end

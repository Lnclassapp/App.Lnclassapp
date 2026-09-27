require "test_helper"

module Policies
  module Assessment
    class StartSessionPolicyTest < ActiveSupport::TestCase
      Exercise = Data.define(:readable_chain_published?)

      def call(role, readable = true)
        actor = role && Entities::Identity::Actor.new(user_id: 1, role:)
        StartSessionPolicy.new.call(actor:, exercise: Exercise.new(readable))
      end

      test "un élève démarre un exercice publié, sans assignation" do
        assert call(:student).success?
      end

      test "refuse un exercice ou un parent non publié" do
        assert_equal [ :not_published ], call(:student, false).errors[:base]
      end

      test "réservé aux élèves" do
        %i[teacher school_admin team].each { |role| assert_equal :forbidden, call(role).code }
        assert_equal :forbidden, call(nil).code
      end
    end
  end
end

require "test_helper"

module Policies
  module Assessment
    class RevealAnswersPolicyTest < ActiveSupport::TestCase
      Exercise = Struct.new(:readable_chain_published?)

      def call(role, readable: true)
        actor = role && Entities::Identity::Actor.new(user_id: 1, role:)
        RevealAnswersPolicy.new.call(actor:, exercise: Exercise.new(readable))
      end

      test "l'enseignant voit la correction de tout exercice lisible, assigné ou non" do
        assert call(:teacher).success?
      end

      test "l'enseignant ne voit pas la correction d'un brouillon, sans en confirmer l'existence" do
        assert_equal :not_found, call(:teacher, readable: false).code
      end

      test "l'équipe voit la correction de tout exercice, même en brouillon" do
        assert call(:team, readable: false).success?
      end

      test "l'élève, la direction et le visiteur ne voient jamais les bonnes réponses" do
        assert_equal :forbidden, call(:student).code
        assert_equal :forbidden, call(:school_admin).code
        assert_equal :forbidden, call(nil).code
      end
    end
  end
end

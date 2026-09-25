require "test_helper"

module Policies
  module Assessment
    class RevealAnswersPolicyTest < ActiveSupport::TestCase
      def call(role, question_id: 4, attempted: [ 4 ])
        actor = role && Entities::Identity::Actor.new(user_id: 1, role:)
        RevealAnswersPolicy.new.call(actor:, question_id:, attempted_question_ids: attempted)
      end

      test "l'élève voit la correction d'une question déjà tentée" do
        assert call(:student).success?
        assert_equal :forbidden, call(:student, attempted: [ 3 ]).code
      end

      test "l'équipe voit tout, même hors session" do
        assert RevealAnswersPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role: :team)).success?
      end

      test "l'enseignant voit toujours les bonnes réponses, hors session" do
        assert RevealAnswersPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role: :teacher)).success?
      end

      test "l'élève ne voit pas la correction d'une question non tentée, même hors session" do
        assert_equal :forbidden, RevealAnswersPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role: :student)).code
      end

      test "la direction et le visiteur ne voient jamais les bonnes réponses" do
        assert_equal :forbidden, call(:school_admin).code
        assert_equal :forbidden, call(nil).code
      end
    end
  end
end

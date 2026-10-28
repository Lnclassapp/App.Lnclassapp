require "test_helper"

module Policies
  module Assessment
    # CA-07 (ADR-0115 §4) : l'équipe et l'enseignant comme RevealAnswersPolicy ; l'élève auteur d'une copie vérifiée seulement.
    class RevealCorrectionPolicyTest < ActiveSupport::TestCase
      Exercise = Struct.new(:readable_chain_published?)
      Session = Struct.new(:student_id, :status) do
        def completed? = status == "completed"
      end

      def call(role, status: "completed", author: 1, readable: true, user_id: 1)
        actor = role && Entities::Identity::Actor.new(user_id:, role:)
        RevealCorrectionPolicy.new.call(actor:, exercise: Exercise.new(readable), session: Session.new(author, status))
      end

      test "l'élève auteur d'une copie vérifiée voit la correction" do
        assert call(:student).success?
      end

      test "l'élève ne voit rien d'une copie en cours ni d'une copie abandonnée" do
        assert_equal :forbidden, call(:student, status: "started").code
        assert_equal :forbidden, call(:student, status: "abandoned").code
      end

      test "un autre élève ne voit jamais la correction, même d'une copie vérifiée" do
        assert_equal :forbidden, call(:student, author: 2).code
      end

      test "l'élève voit la correction de sa copie même si l'exercice n'est plus lisible (archivé par un réimport)" do
        assert call(:student, readable: false).success?
      end

      test "l'équipe voit la correction de tout exercice, même en brouillon" do
        assert call(:team, readable: false).success?
      end

      test "l'enseignant voit la correction d'un exercice lisible, jamais d'un brouillon" do
        assert call(:teacher).success?
        assert_equal :not_found, call(:teacher, readable: false).code
      end

      test "la direction et le visiteur ne voient rien" do
        assert_equal :forbidden, call(:school_admin).code
        assert_equal :forbidden, call(nil).code
      end
    end
  end
end

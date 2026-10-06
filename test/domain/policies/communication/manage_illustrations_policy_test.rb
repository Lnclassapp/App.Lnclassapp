require "test_helper"

# ADR-0081 §4.3, AV-11 : la bibliothèque d'illustrations d'annonce s'écrit par l'équipe seule, quel que soit son rôle
# d'équipe ; tout autre acteur, et le visiteur, reçoivent :forbidden.
module Policies
  module Communication
    class ManageIllustrationsPolicyTest < ActiveSupport::TestCase
      def actor(role, team_role = nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:)

      test "AV-11 — l'équipe gère la bibliothèque, Administration, Contenu et Terrain compris" do
        %w[admin content field].each { assert ManageIllustrationsPolicy.new.call(actor: actor(:team, it)).success?, it }
      end

      test "AV-11 — l'enseignant, la direction, l'élève et le visiteur reçoivent :forbidden" do
        [ actor(:teacher), actor(:school_admin), actor(:student), nil ].each do |someone|
          assert_equal :forbidden, ManageIllustrationsPolicy.new.call(actor: someone).code, someone.inspect
        end
      end
    end
  end
end

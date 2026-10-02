require "test_helper"

# ADR-0073 §4.3, BL-07, BL-08 : le blog est géré par l'équipe Administration et Contenu, et par personne d'autre.
module Policies
  module Communication
    class ManageArticlesPolicyTest < ActiveSupport::TestCase
      def actor(role, team_role = nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:)

      test "l'équipe Administration et Contenu gère le blog" do
        %w[admin content].each { assert ManageArticlesPolicy.new.call(actor: actor(:team, it)).success?, it }
      end

      test "le Terrain, l'enseignant, l'élève, la direction et le visiteur reçoivent :forbidden" do
        [ actor(:team, "field"), actor(:teacher), actor(:student), actor(:school_admin), nil ].each do |someone|
          assert_equal :forbidden, ManageArticlesPolicy.new.call(actor: someone).code, someone.inspect
        end
      end
    end
  end
end

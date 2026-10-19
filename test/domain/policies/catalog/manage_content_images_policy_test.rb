require "test_helper"

# ADR-0104, PRD §2 : seules l'équipe `admin` et `content` gèrent les images de cours.
module Policies
  module Catalog
    class ManageContentImagesPolicyTest < ActiveSupport::TestCase
      def actor(role, team_role = nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:)

      test "admin et contenu : oui ; terrain, enseignant, élève, direction, visiteur : non" do
        assert ManageContentImagesPolicy.new.call(actor: actor(:team, "admin")).success?
        assert ManageContentImagesPolicy.new.call(actor: actor(:team, "content")).success?
        [ actor(:team, "field"), actor(:teacher), actor(:student), actor(:school_admin), nil ].each do |someone|
          assert_equal :forbidden, ManageContentImagesPolicy.new.call(actor: someone).code
        end
      end
    end
  end
end

require "test_helper"

# ADR-0074 §4.2, BL-04, BL-05 : un article publié se lit par tous ; un brouillon est introuvable et un archivé retiré pour
# qui ne gère pas le blog ; qui le gère lit tout état (aperçu).
module Policies
  module Communication
    class ReadArticlePolicyTest < ActiveSupport::TestCase
      Detail = Data.define(:status)

      def actor(role, team_role = nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:)
      def read(someone, status) = ReadArticlePolicy.new.call(actor: someone, article: Detail.new(status:))

      def outsiders = [ nil, actor(:student), actor(:teacher), actor(:school_admin), actor(:team, "field") ]

      test "un article publié se lit par tous, visiteur compris" do
        (outsiders + [ actor(:team, "admin") ]).each { assert read(it, "published").success?, it.inspect }
      end

      test "BL-04, BL-05 : un brouillon est introuvable et un archivé retiré pour qui ne gère pas le blog" do
        outsiders.each do |someone|
          assert_equal :not_found, read(someone, "draft").code, someone.inspect
          assert_equal :expired, read(someone, "archived").code, someone.inspect
        end
      end

      test "l'équipe Administration et Contenu lit tout état" do
        %w[admin content].product(%w[draft published archived]).each do |team_role, status|
          assert read(actor(:team, team_role), status).success?, "#{team_role} #{status}"
        end
      end
    end
  end
end

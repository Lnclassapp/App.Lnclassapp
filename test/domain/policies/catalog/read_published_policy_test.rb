require "test_helper"

module Policies
  module Catalog
    class ReadPublishedPolicyTest < ActiveSupport::TestCase
      Content = Data.define(:readable_chain_published?)

      def actor(role) = Entities::Identity::Actor.new(user_id: 1, role:)
      def call(actor, readable) = ReadPublishedPolicy.new.call(actor:, content: Content.new(readable))

      test "tout acteur connecté lit un contenu dont la chaîne est publiée" do
        %i[student teacher school_admin team].each { |role| assert call(actor(role), true).success? }
      end

      test "l'équipe lit aussi brouillons et archives" do
        assert call(actor(:team), false).success?
      end

      test "un brouillon répond :not_found aux autres rôles" do
        %i[student teacher school_admin].each { |role| assert_equal :not_found, call(actor(role), false).code }
      end

      test "l'anonyme est refusé" do
        assert_equal :forbidden, call(nil, true).code
      end
    end
  end
end

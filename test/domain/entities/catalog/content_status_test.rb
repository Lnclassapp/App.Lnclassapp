require "test_helper"

module Entities
  module Catalog
    class ContentStatusTest < ActiveSupport::TestCase
      def transition(from, to, parent_published: true) = ContentStatus.transition(from:, to:, parent_published:)

      test "brouillon et archivé se publient si le parent est publié" do
        assert_equal "published", transition("draft", "published").value
        assert transition("archived", "published").success?
        assert_equal [ :parent_not_published ], transition("draft", "published", parent_published: false).errors[:base]
      end

      test "un contenu publié s'archive même si son parent ne l'est plus" do
        assert transition("published", "archived", parent_published: false).success?
      end

      test "le retour au brouillon et les sauts sont interdits" do
        [ %w[published draft], %w[archived draft], %w[draft archived], %w[published published], %w[unknown published] ].each do |from, to|
          result = transition(from, to)

          assert_equal :conflict, result.code
          assert_equal [ :transition_not_allowed ], result.errors[:base]
        end
      end
    end
  end
end

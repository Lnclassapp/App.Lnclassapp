require "test_helper"

module Queries
  module Communication
    # BL-19, BL-05 (ADR-0073 §4.6): the sitemap lists published articles only, each with the date it last changed.
    class SitemapQueryTest < ActiveSupport::TestCase
      setup { @query = SitemapQuery.new }

      test "no published article, no row" do
        create_article(status: "draft")
        create_article(status: "archived")

        assert_empty @query.call
      end

      test "the published articles, newest publication first, with their slug and updated_at" do
        older = create_article(title: "Réviser le bac", published_at: Time.zone.local(2026, 9, 1, 8))
        newer = create_article(title: "La rentrée", published_at: Time.zone.local(2026, 9, 20, 8))
        older.update_columns(updated_at: Time.zone.local(2026, 9, 25, 10, 30))
        newer.update_columns(updated_at: Time.zone.local(2026, 9, 21, 9))

        assert_equal [ SitemapQuery::Row.new(slug: "la-rentree", updated_at: Time.zone.local(2026, 9, 21, 9)),
                       SitemapQuery::Row.new(slug: "reviser-le-bac", updated_at: Time.zone.local(2026, 9, 25, 10, 30)) ],
                     @query.call
      end

      test "neither a draft nor an archived article (BL-05)" do
        published = create_article(title: "En ligne")
        create_article(status: "draft", title: "Brouillon")
        create_article(status: "archived", title: "Archivé")

        assert_equal [ published.slug ], @query.call.map(&:slug)
      end

      test "one query, whatever the number of articles" do
        3.times { create_article }

        assert_queries_count(1) { @query.call }
      end
    end
  end
end

require "test_helper"

module Queries
  module Communication
    # UDR-0066 §3.1, ADR-0074 §4.7 et §4.8 : la page d'un article lit l'article, sa signature, sa couverture et son texte
    # en une requête, quel que soit son état (la règle de lecture est en aval) ; la query tranche la signature (BL-18).
    class ArticleDetailQueryTest < ActiveSupport::TestCase
      setup do
        @query = ArticleDetailQuery.new
        @author = create_team_member(team_role: "content", second_factor: false, first_name: "Aya", last_name: "Bamba")
      end

      test "a published article, with its cover, its publication day and its body, in one query" do
        cover = create_article_image
        article = create_article(author: @author, title: "Réviser le BEPC", excerpt: "Un plan simple.", cover:,
                                 cover_alt: "Une élève qui révise", published_at: Time.zone.local(2026, 10, 5, 8),
                                 body: "<div>Quatre semaines suffisent.</div>")

        detail = assert_queries_count(1) { @query.call(slug: article.slug) }

        assert_equal [ article.id, article.slug, "Réviser le BEPC", "Un plan simple.", "published", Date.new(2026, 10, 5) ],
                     [ detail.id, detail.slug, detail.title, detail.excerpt, detail.status, detail.published_on ]
        assert_equal ArticleDetailQuery::Image.new(public_id: cover.public_id, alt: "Une élève qui révise", width: 64, height: 48),
                     detail.cover
        assert_instance_of ActionText::Content, detail.body
        assert_includes detail.body.to_html, "Quatre semaines suffisent."
      end

      test "an unknown address reads nothing" do
        assert_nil @query.call(slug: "inconnu")
      end

      test "a draft is read, without a date nor a cover; an archived article keeps its first publication day" do
        draft = create_article(author: @author, status: "draft", excerpt: nil)
        archived = create_article(author: @author, status: "archived", published_at: Time.zone.local(2026, 9, 1, 10))

        assert_equal [ "draft", nil, nil, nil ], @query.call(slug: draft.slug).then { [ it.status, it.published_on, it.cover, it.excerpt ] }
        assert_equal [ "archived", Date.new(2026, 9, 1) ], @query.call(slug: archived.slug).then { [ it.status, it.published_on ] }
      end

      test "an article without a body row has no body" do
        draft = create_article(author: @author, status: "draft")
        ActionText::RichText.where(record_type: Orm::Article.name, record_id: draft.id).delete_all

        assert_nil @query.call(slug: draft.slug).body
      end

      test "BL-18: the author's name for an article signed by them, never for one signed « L'équipe Lnclass »" do
        signed = create_article(author: @author, signature: "author")
        team = create_article(author: @author, signature: "team")

        assert_equal "Aya Bamba", @query.call(slug: signed.slug).author_name
        assert_nil @query.call(slug: team.slug).author_name
      end

      test "BL-18: once the author is anonymized, the article signed by their name has no author name" do
        signed = create_article(author: @author, signature: "author")
        @author.update_columns(anonymized_at: Time.current)

        assert_nil @query.call(slug: signed.slug).author_name
      end
    end
  end
end

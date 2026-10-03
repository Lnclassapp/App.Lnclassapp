require "test_helper"

module Queries
  module Communication
    # UDR-0066 §3.1 : la liste publique du blog. Publiés seulement (BL-05), du plus récent au plus ancien, dix par page
    # (BL-01) ; any? dit, en une requête, si le lien « Blog » existe (BL-06).
    class PublishedArticlesQueryTest < ActiveSupport::TestCase
      Image = ArticleDetailQuery::Image

      setup do
        @query = PublishedArticlesQuery.new
        @author = create_team_member(team_role: "content", second_factor: false)
      end

      def publish(title, at, **attributes) = create_article(author: @author, title:, published_at: at, **attributes)

      test "BL-01: a row carries the slug, the title, the excerpt, the publication day and the cover" do
        cover = create_article_image
        article = publish("Réviser le BEPC en 4 semaines", Time.zone.local(2026, 10, 5, 23, 30), excerpt: "Un plan simple.",
                                                                                                cover:, cover_alt: "Une élève")

        row = @query.call(page: 1).rows.sole

        assert_equal [ article.slug, "Réviser le BEPC en 4 semaines", "Un plan simple.", Date.new(2026, 10, 5) ],
                     [ row.slug, row.title, row.excerpt, row.published_on ]
        assert_equal Image.new(public_id: cover.public_id, alt: "Une élève", width: 64, height: 48), row.cover
      end

      test "an article without a cover has no image" do
        publish("Sans couverture", 1.day.ago)

        assert_nil @query.call(page: 1).rows.sole.cover
      end

      test "BL-05: neither a draft nor an archived article is listed" do
        publish("En ligne", 1.day.ago)
        create_article(author: @author, status: "draft", title: "Brouillon")
        create_article(author: @author, status: "archived", title: "Archivé")

        page = @query.call(page: 1)

        assert_equal [ "En ligne" ], page.rows.map(&:title)
        assert_equal 1, page.pages
      end

      test "BL-01: the most recent first; on the same date and time, the latest created first" do
        same = Time.zone.local(2026, 10, 3, 9)
        publish("Plus ancien", Time.zone.local(2026, 9, 1, 9))
        publish("Même heure, créé avant", same)
        publish("Même heure, créé après", same)
        publish("Plus récent", Time.zone.local(2026, 10, 4, 7))

        assert_equal [ "Plus récent", "Même heure, créé après", "Même heure, créé avant", "Plus ancien" ],
                     @query.call(page: 1).rows.map(&:title)
      end

      test "BL-01: ten articles a page; eleven articles make two pages, the oldest alone on the second" do
        11.times { |index| publish("Article #{index + 1}", Time.zone.local(2026, 9, 1 + index, 8)) }

        first = @query.call(page: 1)
        second = @query.call(page: 2)

        assert_equal [ 10, 1, 2 ], [ PublishedArticlesQuery::PER_PAGE, first.page, first.pages ]
        assert_equal (2..11).map { "Article #{it}" }.reverse, first.rows.map(&:title)
        assert_equal [ [ "Article 1" ], 2, 2 ], [ second.rows.map(&:title), second.page, second.pages ]
      end

      test "with no article there is one empty page, and a page beyond the last is empty" do
        assert_equal [ [], 1, 1 ], @query.call(page: 1).then { [ it.rows, it.page, it.pages ] }

        publish("Seul", 1.day.ago)

        assert_equal [ [], 3, 1 ], @query.call(page: 3).then { [ it.rows, it.page, it.pages ] }
      end

      test "a page is read in two queries, cover included" do
        3.times { publish("Avec couverture #{it}", 1.day.ago, cover: create_article_image) }

        assert_queries_count(2) { @query.call(page: 1).rows.each(&:cover) }
      end

      test "BL-06: any? is false until an article is published, in one query" do
        create_article(author: @author, status: "draft")
        create_article(author: @author, status: "archived")

        assert_queries_count(1) { assert_not @query.any? }

        publish("Premier", 1.day.ago)

        assert_queries_count(1) { assert @query.any? }
      end
    end
  end
end

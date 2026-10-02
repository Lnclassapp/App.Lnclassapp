require "test_helper"

# UDR-0065 §3.0, §3.2 : la liste de gestion du blog montre tous les articles, du plus récemment modifié au plus ancien,
# 20 par page, avec le nom réel de l'auteur et le nombre de lectures (BL-17).
module Queries
  module Communication
    class TeamArticlesQueryTest < ActiveSupport::TestCase
      setup do
        @author = create_team_member(team_role: "content", second_factor: false, first_name: "Aya", last_name: "Traoré")
      end

      def query(**) = TeamArticlesQuery.new.call(**)

      # Action Text touche l'article à l'enregistrement de son texte : la date de modification se pose ensuite.
      def team_article(updated_at: nil, **attributes)
        create_article(author: @author, **attributes).tap { it.update_columns(updated_at:) if updated_at }
      end

      test "tous les états, du plus récemment modifié au plus ancien, avec leurs dates, signature et auteur" do
        draft = team_article(status: "draft", title: "Brouillon", updated_at: 1.day.ago)
        published = team_article(status: "published", title: "Publié", signature: "author",
                                 published_at: Time.utc(2026, 10, 5, 9), updated_at: 1.hour.ago)
        archived = team_article(status: "archived", title: "Archivé", updated_at: 3.days.ago)

        page = query

        assert_equal [ 3, 1, 1 ], [ page.total_count, page.page, page.pages ]
        assert_equal %w[Publié Brouillon Archivé], page.rows.map(&:title)
        row = page.rows.first
        assert_equal [ published.public_id, published.slug, "published", "author", "Aya Traoré", Time.utc(2026, 10, 5, 9), nil ],
                     [ row.public_id, row.slug, row.status, row.signature, row.author_name, row.published_at, row.archived_at ]
        assert_in_delta published.updated_at, row.updated_at, 1.second
        assert_nil page.rows.second.published_at
        assert_equal draft.public_id, page.rows.second.public_id
        assert_equal archived.archived_at, page.rows.third.archived_at
      end

      test "BL-17 : chaque ligne porte le nombre de lectures, un archivé garde le sien" do
        team_article(status: "published", reads_count: 12)
        team_article(status: "archived", reads_count: 3, updated_at: 1.day.ago)

        assert_equal [ 12, 3 ], query.rows.map(&:reads_count)
      end

      test "le nom de l'auteur est le nom réel, même pour un article signé « L'équipe Lnclass »" do
        team_article(signature: "team")

        assert_equal "Aya Traoré", query.rows.sole.author_name
      end

      test "20 articles par page ; une page hors bornes ou illisible revient dans les bornes" do
        21.times { team_article(status: "draft", title: format("Article %02d", it), updated_at: it.minutes.ago) }

        first = query
        assert_equal [ 21, 2, 20 ], [ first.total_count, first.pages, first.rows.size ]
        assert_equal [ "Article 00", "Article 19" ], [ first.rows.first.title, first.rows.last.title ]
        assert_equal [ 2, [ "Article 20" ] ], query(page: "2").then { [ it.page, it.rows.map(&:title) ] }
        assert_equal 2, query(page: "99").page
        assert_equal 1, query(page: "abc").page
        assert_equal 1, query(page: [ "2" ]).page
      end

      test "aucun article : une page vide" do
        page = query

        assert_equal [ 0, 1, 1, [] ], [ page.total_count, page.page, page.pages, page.rows ]
      end

      test "find relit une ligne par son public_id, ou rien" do
        article = team_article(status: "draft", title: "Brouillon")

        assert_equal [ "Brouillon", "draft", "Aya Traoré" ],
                     TeamArticlesQuery.new.find(public_id: article.public_id).then { [ it.title, it.status, it.author_name ] }
        assert_nil TeamArticlesQuery.new.find(public_id: "inconnu")
      end
    end
  end
end

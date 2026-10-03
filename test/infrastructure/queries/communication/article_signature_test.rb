require "test_helper"

module Queries
  module Communication
    # ADR-0074 §4.8, BL-18 : la signature d'un article public. Le nom de l'auteur n'est lu que pour un article signé de
    # son nom, et tant que son compte n'est pas anonymisé ; NULL s'affiche « L'équipe Lnclass ».
    class ArticleSignatureTest < ActiveSupport::TestCase
      def author_name(article)
        Orm::Article.joins(:author).where(id: article.id).pick(Arel.sql(ArticleSignature::AUTHOR_NAME))
      end

      setup { @author = create_team_member(team_role: "content", second_factor: false, first_name: "Aya", last_name: "Bamba") }

      test "an article signed by its author shows the author's full name" do
        assert_equal "Aya Bamba", author_name(create_article(author: @author, signature: "author"))
      end

      test "BL-18: an article signed « L'équipe Lnclass » never selects its author's name" do
        assert_nil author_name(create_article(author: @author, signature: "team"))
      end

      test "BL-18: once the author's account is anonymized, an article signed by their name falls back to NULL" do
        signed = create_article(author: @author, signature: "author")
        team = create_article(author: @author, signature: "team")
        @author.update_columns(anonymized_at: Time.current)

        assert_nil author_name(signed)
        assert_nil author_name(team)
      end
    end
  end
end

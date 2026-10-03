# 🔌 INFRA · Queries::Communication::PublishedArticlesQuery
# Rôle : liste publique du blog, publiés seulement, du plus récent au plus ancien, dix par page ; le blog a-t-il un article ?
# ADR  : 0026, 0074 · UDR : 0066 (§3.1, §3.5)
module Queries
  module Communication
    class PublishedArticlesQuery
      PER_PAGE = 10
      Row = Data.define(:slug, :title, :excerpt, :published_on, :cover)
      Page = Data.define(:rows, :page, :pages)

      COLUMNS = [ "articles.slug", "articles.title", "articles.excerpt", "articles.published_at",
                  *ArticleDetailQuery::COVER_COLUMNS ].freeze

      # page : entier ≥ 1, lu par le contrôleur. Au-delà de la dernière page, aucune ligne (le contrôleur répond 404).
      # → Page, en deux requêtes : le nombre de pages, puis la page, couverture comprise.
      def call(page:)
        pages = [ published.count.fdiv(PER_PAGE).ceil, 1 ].max
        rows = published.joins(ArticleDetailQuery::COVER)
                        .order(published_at: :desc, id: :desc) # l'index partiel index_articles_published
                        .offset((page - 1) * PER_PAGE).limit(PER_PAGE).pluck(*COLUMNS)
        Page.new(rows: rows.map { row(*it) }, page:, pages:)
      end

      # Une requête EXISTS : lue par PublicPagesHelper#blog_link, à chaque rendu du pied de page (BL-06).
      def any? = published.exists?

      private

      def published = Orm::Article.where(status: "published")

      def row(slug, title, excerpt, published_at, *cover)
        Row.new(slug:, title:, excerpt:, published_on: published_at.to_date, cover: ArticleDetailQuery.image(*cover))
      end
    end
  end
end

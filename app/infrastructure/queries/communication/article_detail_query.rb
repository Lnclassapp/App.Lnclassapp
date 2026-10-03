# 🔌 INFRA · Queries::Communication::ArticleDetailQuery
# Rôle : un article du blog par son slug, tous états : signature tranchée, couverture et texte, en une requête
# ADR  : 0026, 0074 (§4.7, §4.8) · UDR : 0066 (§3.1)
module Queries
  module Communication
    class ArticleDetailQuery
      # Une image servie par Lnclass (blog_image_path) : dimensions en pixels, alt lu sur la page de l'article.
      Image = Data.define(:public_id, :alt, :width, :height)
      # author_name : nil pour « L'équipe Lnclass » (ArticleSignature). body : ActionText::Content, rendu par Action Text
      # (assaini, .trix-content), ou nil. id : pour le compteur de lectures (RecordArticleRead).
      Detail = Data.define(:id, :slug, :title, :excerpt, :status, :published_on, :author_name, :cover, :body)

      RICH_TEXT = "LEFT OUTER JOIN action_text_rich_texts ON action_text_rich_texts.record_type = 'Orm::Article' " \
                  "AND action_text_rich_texts.record_id = articles.id AND action_text_rich_texts.name = 'body'".freeze
      COVER = "LEFT OUTER JOIN article_images covers ON covers.id = articles.cover_image_id".freeze
      COVER_COLUMNS = %w[covers.public_id articles.cover_alt covers.width covers.height].freeze
      COLUMNS = [ "articles.id", "articles.slug", "articles.title", "articles.excerpt", "articles.status", "articles.published_at",
                  Arel.sql(ArticleSignature::AUTHOR_NAME), *COVER_COLUMNS, "action_text_rich_texts.body" ].freeze

      # → Detail | nil. La lecture d'un brouillon ou d'un archivé est l'affaire de ReadArticlePolicy, en aval.
      def call(slug:)
        values = Orm::Article.joins(:author).joins(COVER).joins(RICH_TEXT).where(slug:).pick(*COLUMNS)
        return if values.nil?

        id, slug, title, excerpt, status, published_at, author_name, *cover, body = values
        Detail.new(id:, slug:, title:, excerpt:, status:, published_on: published_at&.to_date, author_name:,
                   cover: self.class.image(*cover), body: (ActionText::Content.new(body) if body))
      end

      # → Image | nil, depuis les colonnes COVER_COLUMNS (lues aussi par PublishedArticlesQuery).
      def self.image(public_id, alt, width, height) = (Image.new(public_id:, alt:, width:, height:) if public_id)
    end
  end
end

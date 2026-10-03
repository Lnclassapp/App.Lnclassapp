# 🔌 INFRA · Orm::Article
# Rôle : table articles, articles du blog (brouillon, publié, archivé) : public_id pour l'équipe, slug figé pour le public
# ADR  : 0029, 0035, 0074
module Orm
  class Article < ApplicationRecord
    include HasPublicId
    include HasFrozenSlug

    self.table_name = "articles"

    has_frozen_slug from: :title

    belongs_to :author, class_name: "Orm::User"
    # La couverture est une ligne d'article_images comme les autres, rattachée à l'article.
    belongs_to :cover_image, class_name: "Orm::ArticleImage", optional: true
    has_many :images, class_name: "Orm::ArticleImage", inverse_of: :article, dependent: :restrict_with_error

    has_rich_text :body

    # public_id dans les adresses de l'équipe ; le slug ne sert qu'à l'adresse publique (blog_article_path).
    def to_param = public_id
  end
end

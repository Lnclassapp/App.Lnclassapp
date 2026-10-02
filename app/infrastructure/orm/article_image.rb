# 🔌 INFRA · Orm::ArticleImage
# Rôle : image d'un article (couverture ou texte), vérifiée, sans métadonnées ; pièce jointe Action Text par sgid
# ADR  : 0029, 0060, 0073
module Orm
  class ArticleImage < ApplicationRecord
    include HasPublicId
    include ActionText::Attachable

    self.table_name = "article_images"

    belongs_to :article, class_name: "Orm::Article", optional: true
    has_one_attached :file

    # Rendu public d'une image du texte : partiel du Lot D, qui reçoit la ligne (public_id, alt, width, height).
    def to_attachable_partial_path = "communication/articles/body_image"

    # Dans l'éditeur (to_trix_html), aucun partiel : Trix montre l'image par son adresse et ses dimensions.
    def to_trix_content_attachment_partial_path = nil

    # Une ligne ne change jamais de fichier : son adresse publique (blog_image_path) est versionnée par construction.
    def to_rich_text_attributes(attributes = {})
      super.merge(url: Rails.application.routes.url_helpers.blog_image_path(public_id), width:, height:)
    end
  end
end

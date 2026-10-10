# 🔌 INFRA · Orm::EssentialImage
# Rôle : image d'une fiche, vérifiée, sans métadonnées ; pièce jointe Action Text du texte de la fiche par sgid
# ADR  : 0029, 0060, 0089
module Orm
  class EssentialImage < ApplicationRecord
    include HasPublicId
    include ActionText::Attachable

    self.table_name = "essential_images"

    belongs_to :essential, class_name: "Orm::Essential", optional: true, inverse_of: :images
    has_one_attached :file

    # Rendu de lecture d'une image du texte (UDR-0084 §3.3), qui reçoit la ligne (public_id, alt, width, height).
    def to_attachable_partial_path = "catalog/essentials/body_image"

    # Dans l'éditeur (to_trix_html), aucun partiel : Trix montre l'image par son adresse et ses dimensions.
    def to_trix_content_attachment_partial_path = nil

    # Une ligne ne change jamais de fichier : son adresse (essential_image_path) est versionnée par construction.
    def to_rich_text_attributes(attributes = {})
      super.merge(url: Rails.application.routes.url_helpers.essential_image_path(public_id), width:, height:)
    end
  end
end

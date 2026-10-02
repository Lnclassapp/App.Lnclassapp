# 🧠 DOMAINE · Entities::Communication::ArticleImage
# Rôle : une image d'article (couverture ou image du texte) et ses plafonds, lus par les vues, le JavaScript et le serveur
# ADR  : 0060, 0073 · UDR : 0065
module Entities
  module Communication
    # alt : texte de remplacement d'une image du texte ; celui de la couverture est porté par l'article (cover_alt).
    ArticleImage = Data.define(:public_id, :id, :article_id, :alt, :content_type, :byte_size, :width, :height) do
      def initialize(public_id:, id: nil, article_id: nil, alt: nil, content_type: nil, byte_size: nil, width: nil, height: nil)
        super
      end

      def alt? = !alt.to_s.strip.empty?
    end
    # Ce que lit Entities::Shared::ImageHeader : ni GIF, ni WebP animé, ni SVG.
    ArticleImage::CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
    ArticleImage::MAX_MEGABYTES = 1
    ArticleImage::MAX_BYTES = ArticleImage::MAX_MEGABYTES * 1024 * 1024
    ArticleImage::MAX_SIDE = 1600
    # Images du texte d'un article ; la couverture n'est pas comptée.
    ArticleImage::MAX_PER_ARTICLE = 10
    ArticleImage::ALT_MAX = 150
  end
end

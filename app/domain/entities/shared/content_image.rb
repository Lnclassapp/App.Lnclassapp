# 🧠 DOMAINE · Entities::Shared::ContentImage
# Rôle : une image d'un contenu pédagogique (fiche ou question) et ses plafonds, lus par les vues, le JavaScript et le serveur
# ADR  : 0060, 0074, 0089 · UDR : 0084
module Entities
  module Shared
    # owner_id : la fiche ou la question qui cite l'image ; nil entre l'envoi et le premier enregistrement.
    ContentImage = Data.define(:public_id, :id, :owner_id, :alt, :content_type, :byte_size, :width, :height) do
      def initialize(public_id:, id: nil, owner_id: nil, alt: nil, content_type: nil, byte_size: nil, width: nil, height: nil)
        super
      end

      def alt? = !alt.to_s.strip.empty?
    end
    # Ce que lit Entities::Shared::ImageHeader : ni GIF, ni WebP animé, ni SVG (ADR-0089 §4.1).
    ContentImage::CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
    # L'élève révise sur téléphone, avec peu de données : 300 Ko au plus par image (grill, question 6).
    ContentImage::MAX_KILOBYTES = 300
    ContentImage::MAX_BYTES = ContentImage::MAX_KILOBYTES * 1024
    ContentImage::MAX_SIDE = 1200
    # Plafond anti-abus, pas une limite métier : le nombre d'images dépend de la leçon.
    ContentImage::MAX_PER_ESSENTIAL = 30
    ContentImage::ALT_MAX = 150
  end
end

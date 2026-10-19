# 🧠 DOMAINE · Entities::Catalog::Essential
# Rôle : une fiche essentielle d'un cours ; lisible si elle et son cours sont publiés
# ADR  : 0035, 0037, 0105
module Entities
  module Catalog
    class Essential
      include ActiveModel::Model

      NAME_MAX = 150
      SUBTITLE_MAX = 150
      # Plafond anti-abus du texte d'une fiche, en caractères (200 Ko) : une fiche de cours en tient dix fois moins. Il borne
      # le temps des motifs qui relisent le texte (menace.md, n° 13) ; le schéma d'import en porte le même chiffre.
      CONTENT_MAX = 200 * 1024

      attr_accessor :id, :slug, :course_id, :position, :author_id, :status, :published_at, :archived_at,
                    :content, :course_status
      attr_reader :name, :subtitle
      # images : [Shared::ContentImage], celles que cite le texte, dans son ordre, chacune avec son alt (ADR-0105).
      attr_writer :images

      validates :name, presence: true, length: { maximum: NAME_MAX }
      validates :subtitle, length: { maximum: SUBTITLE_MAX }
      validates :course_id, presence: true
      validates :status, inclusion: { in: Entities::Shared::ContentStatus::VALUES }

      def name=(value)
        @name = value&.squish
      end

      def subtitle=(value)
        @subtitle = value&.squish.presence
      end

      def images = @images || []
      # Les emplacements annoncés par l'import et pas encore remplacés par une image (ADR-0105 §4.3).
      def image_slots = ImageSlot.scan(content)

      # Ce qui empêche de publier : emplacements mal écrits, emplacements restants et images sans texte de remplacement
      # → { Symbol => valeur }.
      def image_publish_errors
        errors = {}
        malformed = ImageSlot.malformed_count(content)
        errors[:image_slots_malformed] = malformed if malformed.positive?
        errors[:image_slots_left] = image_slots.size if image_slots.any?
        missing = images.reject(&:alt?).map(&:public_id)
        errors[:image_alts_blank] = missing if missing.any?
        errors
      end

      def published? = status == "published"
      def course_published? = course_status == "published"
      def readable_chain_published? = published? && course_published?
    end
  end
end

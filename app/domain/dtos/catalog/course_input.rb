# 🧠 DOMAINE · Dtos::Catalog::CourseInput
# Rôle : saisie d'un cours (création, modification) : référentiel par slugs, contenu HTML de l'éditeur riche en chaîne
# ADR  : 0026, 0035, 0037
module Dtos
  module Catalog
    class CourseInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :name, :string
      attribute :subtitle, :string
      attribute :level_slug, :string
      attribute :series_slug, :string
      attribute :material_slug, :string
      # Le domaine ne connaît pas Action Text : le contenu est le HTML produit par l'éditeur, assaini au rendu.
      attribute :content, :string

      validates :name, presence: true, length: { maximum: Entities::Catalog::Course::NAME_MAX }
      validates :subtitle, length: { maximum: Entities::Catalog::Course::SUBTITLE_MAX }
      validates :level_slug, :material_slug, presence: true

      # Aucun titleize : le nom garde la casse saisie (non-régression CA-05).
      def name
        super.to_s.squish
      end

      def subtitle
        super.to_s.squish.presence
      end

      def level_slug
        super.to_s.strip.presence
      end

      def series_slug
        super.to_s.strip.presence
      end

      def material_slug
        super.to_s.strip.presence
      end

      def content
        super.to_s
      end
    end
  end
end

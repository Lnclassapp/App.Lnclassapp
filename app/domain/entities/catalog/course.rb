# 🧠 DOMAINE · Entities::Catalog::Course
# Rôle : un cours, seule entité pour la lecture et l'écriture ; son nom garde sa casse
# ADR  : 0035, 0037
module Entities
  module Catalog
    class Course
      include ActiveModel::Model

      NAME_MAX = 200
      SUBTITLE_MAX = 150

      attr_accessor :id, :slug, :level_id, :series_id, :material_id, :author_id, :status,
                    :published_at, :archived_at, :content_html
      attr_reader :name, :subtitle

      validates :name, presence: true, length: { maximum: NAME_MAX }
      validates :subtitle, length: { maximum: SUBTITLE_MAX }
      validates :level_id, :material_id, presence: true
      validates :status, inclusion: { in: ContentStatus::VALUES }

      def name=(value)
        @name = value&.squish
      end

      def subtitle=(value)
        @subtitle = value&.squish.presence
      end

      def published? = status == "published"

      # Un cours n'a pas de parent : sa chaîne est publiée s'il l'est.
      def readable_chain_published? = published?
    end
  end
end

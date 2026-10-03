# 🧠 DOMAINE · Entities::Catalog::Essential
# Rôle : une fiche essentielle d'un cours ; lisible si elle et son cours sont publiés
# ADR  : 0035, 0037
module Entities
  module Catalog
    class Essential
      include ActiveModel::Model

      NAME_MAX = 150
      SUBTITLE_MAX = 150

      attr_accessor :id, :slug, :course_id, :position, :author_id, :status, :published_at, :archived_at,
                    :content, :course_status
      attr_reader :name, :subtitle

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

      def published? = status == "published"
      def course_published? = course_status == "published"
      def readable_chain_published? = published? && course_published?
    end
  end
end

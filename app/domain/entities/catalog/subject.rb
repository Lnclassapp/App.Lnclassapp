# 🧠 DOMAINE · Entities::Catalog::Subject
# Rôle : un sujet de devoir d'une leçon (titre, notions mobilisées, ordre) ; ses exercices n'ont pas de notion
# ADR  : 0121 (§4)
module Entities
  module Catalog
    class Subject
      include ActiveModel::Model

      TITLE_MAX = 200
      NOTIONS_MAX = 600

      attr_accessor :id, :course_id, :position
      attr_reader :title, :notions

      validates :title, presence: true, length: { maximum: TITLE_MAX }
      validates :notions, presence: true, length: { maximum: NOTIONS_MAX }
      validates :course_id, presence: true
      validates :position, numericality: { only_integer: true, greater_than: 0 }

      def title=(value)
        @title = value&.squish
      end

      def notions=(value)
        @notions = value&.strip.presence
      end
    end
  end
end

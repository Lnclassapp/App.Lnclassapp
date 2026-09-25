# 🧠 DOMAINE · Entities::Catalog::Material
# Rôle : matière ; sa catégorie obligatoire porte l'icône et la couleur, jamais le nom
# ADR  : 0034, 0037
module Entities
  module Catalog
    class Material
      include ActiveModel::Model

      CATEGORIES = %w[literature science other].freeze
      NAME_MAX = 40
      SHORTNAME_MAX = 10

      attr_accessor :id, :slug, :category
      attr_reader :name, :shortname

      validates :name, presence: true, length: { maximum: NAME_MAX }
      validates :shortname, presence: true, length: { maximum: SHORTNAME_MAX }
      validates :category, inclusion: { in: CATEGORIES }

      def name=(value)
        @name = value&.squish
      end

      def shortname=(value)
        @shortname = value&.squish
      end
    end
  end
end

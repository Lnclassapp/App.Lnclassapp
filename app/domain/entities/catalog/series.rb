# 🧠 DOMAINE · Entities::Catalog::Series
# Rôle : série du second cycle ; son slug figé (a, a1, a2, c, d) est la clé de la génération et des imports
# ADR  : 0029, 0030, 0034
module Entities
  module Catalog
    class Series
      include ActiveModel::Model

      SLUGS = %w[a a1 a2 c d].freeze
      NAME_MAX = 10

      attr_accessor :id, :slug
      attr_reader :name

      validates :name, presence: true, length: { maximum: NAME_MAX }

      def name=(value)
        @name = value&.squish
      end
    end
  end
end

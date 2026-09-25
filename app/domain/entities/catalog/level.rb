# 🧠 DOMAINE · Entities::Catalog::Level
# Rôle : niveau scolaire ; son slug figé (6eme … tle) est la clé de la génération des classes et des imports
# ADR  : 0029, 0030, 0034
module Entities
  module Catalog
    class Level
      include ActiveModel::Model

      CYCLES = %w[first second].freeze
      SLUGS = %w[6eme 5eme 4eme 3eme 2nde 1ere tle].freeze
      NAME_MAX = 20

      attr_accessor :id, :slug, :position, :cycle
      attr_reader :name

      validates :name, presence: true, length: { maximum: NAME_MAX }
      validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :cycle, inclusion: { in: CYCLES }

      def name=(value)
        @name = value&.squish
      end

      def first_cycle? = cycle == "first"
    end
  end
end

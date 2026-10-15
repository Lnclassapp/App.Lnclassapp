# 🔌 INFRA · Repositories::Catalog::ProgramOrder
# Rôle : rang du programme d'une matière, par slug (anciens slugs compris) ; lu par la migration et par la création d'une matière
# ADR  : 0090 (§4.2)
module Repositories
  module Catalog
    module ProgramOrder
      # Rang 1 à 7, dans l'ordre ; une matière absente de la table n'a pas de rang (NULL, après les autres, par nom).
      SLUGS = [ %w[mathematiques maths], %w[physique-chimie pc], %w[svt], %w[francais],
                %w[histoire-geographie histoire-geo hg], %w[edhc], %w[philosophie philo] ].freeze
      RANKS = SLUGS.each.with_index(1).flat_map { |slugs, rank| slugs.map { [ it, rank ] } }.to_h.freeze

      # → Integer | nil
      def self.rank(slug) = RANKS[slug.to_s]
    end
  end
end

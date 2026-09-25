# Référentiel de développement (ADR-0034), construit en mémoire pour les tests du domaine.
module Entities
  module Catalog
    module TaxonomyFixture
      LEVELS = [ [ "6ème", "6eme", "first" ], [ "5ème", "5eme", "first" ], [ "4ème", "4eme", "first" ], [ "3ème", "3eme", "first" ],
                 [ "2nde", "2nde", "second" ], [ "1ère", "1ere", "second" ], [ "Tle", "tle", "second" ] ].freeze
      SERIES = [ [ "A", "a" ], [ "A1", "a1" ], [ "A2", "a2" ], [ "C", "c" ], [ "D", "d" ] ].freeze
      PAIRS = { "2nde" => %w[a c], "1ere" => %w[a1 a2 c d], "tle" => %w[a1 a2 c d] }.freeze

      def self.lookup(levels: LEVELS, pairs: PAIRS)
        level_entities = levels.each_with_index.map do |(name, slug, cycle), index|
          Level.new(id: index + 1, name:, slug:, position: index, cycle:)
        end
        series = SERIES.each_with_index.map { |(name, slug), index| Series.new(id: index + 101, name:, slug:) }
        materials = [ Material.new(id: 201, name: "Physique-Chimie", slug: "physique-chimie", shortname: "PC", category: "science") ]
        links = pairs.flat_map do |level_slug, series_slugs|
          level = level_entities.find { |entity| entity.slug == level_slug }
          level ? series_slugs.map { |slug| [ level.id, series.find { |item| item.slug == slug }.id ] } : []
        end

        TaxonomyLookup.new(levels: level_entities, series:, materials:, pairs: links)
      end
    end
  end
end

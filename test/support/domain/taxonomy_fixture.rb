require Rails.root.join("db/migrate/20260928140100_fill_classroom_plan_entries").to_s

# Référentiel de développement (ADR-0034), construit en mémoire pour les tests du domaine ; et son barème, repris de
# l'ancien barème comme le fait la migration de données (ADR-0058).
module Entities
  module Catalog
    module TaxonomyFixture
      LEVELS = [ [ "6ème", "6eme", "first" ], [ "5ème", "5eme", "first" ], [ "4ème", "4eme", "first" ], [ "3ème", "3eme", "first" ],
                 [ "2nde", "2nde", "second" ], [ "1ère", "1ere", "second" ], [ "Tle", "tle", "second" ] ].freeze
      SERIES = [ [ "A", "a" ], [ "A1", "a1" ], [ "A2", "a2" ], [ "C", "c" ], [ "D", "d" ] ].freeze
      PAIRS = { "2nde" => %w[a c], "1ere" => %w[a1 a2 c d], "tle" => %w[a1 a2 c d] }.freeze

      def self.lookup(levels: LEVELS, pairs: PAIRS, series: SERIES)
        level_entities = levels.each_with_index.map do |(name, slug, cycle), index|
          Level.new(id: index + 1, name:, slug:, position: index, cycle:)
        end
        series = series.each_with_index.map { |(name, slug), index| Series.new(id: index + 101, name:, slug:) }
        materials = [ Material.new(id: 201, name: "Physique-Chimie", slug: "physique-chimie", shortname: "PC", category: "science") ]
        links = pairs.flat_map do |level_slug, series_slugs|
          level = level_entities.find { |entity| entity.slug == level_slug }
          level ? series_slugs.map { |slug| [ level.id, series.find { |item| item.slug == slug }.id ] } : []
        end

        TaxonomyLookup.new(levels: level_entities, series:, materials:, pairs: links)
      end

      # L'ancien barème appliqué au référentiel donné, par slug, comme la reprise (FillClassroomPlanEntries::PLAN).
      def self.plan(lookup = self.lookup)
        entries = FillClassroomPlanEntries::PLAN.flat_map do |school_type, levels|
          levels.flat_map do |level_slug, config|
            level = lookup.level(level_slug)
            level ? plan_entries(school_type, level, config, lookup) : []
          end
        end
        Entities::Classroom::ClassroomPlan.new(entries:)
      end

      def self.plan_entries(school_type, level, config, lookup)
        entry = ->(series, count) { Entities::Classroom::ClassroomPlan::Entry.new(school_type:, level_id: level.id, series_id: series&.id, count:) }
        return [ entry.call(nil, config) ] if config.is_a?(Integer)
        return lookup.series_for(level.id).map { entry.call(it, config[:per_series]) } if config.key?(:per_series)

        config.filter_map do |slug, count|
          series = lookup.find_series(slug)
          entry.call(series, count) if series && lookup.pair?(level.id, series.id)
        end
      end
    end
  end
end

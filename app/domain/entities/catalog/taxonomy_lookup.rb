# 🧠 DOMAINE · Entities::Catalog::TaxonomyLookup
# Rôle : index en mémoire du référentiel, pour générer les classes et résoudre les imports sans requête
# ADR  : 0030, 0034, 0039
module Entities
  module Catalog
    class TaxonomyLookup
      attr_reader :levels, :series, :materials

      # pairs : couples [level_id, series_id] de level_series
      def initialize(levels:, series:, materials:, pairs:)
        @levels = levels.freeze
        @series = series.freeze
        @materials = materials.freeze
        @pairs = pairs.to_set(&:to_a).freeze
        @levels_by_key = index(levels) { |level| [ level.slug, level.name ] }
        @series_by_key = index(series) { |item| [ item.slug, item.name ] }
        @materials_by_key = index(materials) { |material| [ material.slug, material.name, material.shortname ] }
      end

      def level(slug) = @levels.find { |level| level.slug == slug }
      def find_series(slug) = @series.find { |item| item.slug == slug }

      # Un nom saisi (« Physique Chimie ») est comparé après parameterize aux slugs, noms et abrégés.
      def resolve_level(name) = @levels_by_key[name.to_s.parameterize]
      def resolve_series(name) = @series_by_key[name.to_s.parameterize]
      def resolve_material(name) = @materials_by_key[name.to_s.parameterize]

      def pair?(level_id, series_id) = @pairs.include?([ level_id, series_id ])
      def series_for_level(level_id) = @series.select { |item| pair?(level_id, item.id) }

      private

      # Tous les slugs d'abord, puis les autres clés : un nom ne masque jamais le slug d'un autre élément.
      def index(items)
        keys = items.map { |item| yield(item).compact.map { |key| key.to_s.parameterize } }
        keys.map(&:size).max.to_i.times.each_with_object({}) do |rank, index|
          items.zip(keys).each { |item, item_keys| index[item_keys[rank]] ||= item if item_keys[rank] }
        end.freeze
      end
    end
  end
end

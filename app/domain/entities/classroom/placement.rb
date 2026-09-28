# 🧠 DOMAINE · Entities::Classroom::Placement
# Rôle : niveau et série d'une nouvelle classe, contrôlés comme à la génération (collège = premier cycle, couple ouvert)
# ADR  : 0030, 0059 · partagé par CreateClassroom et AddLevelClassroom
module Entities
  module Classroom
    Placement = Data.define(:level, :series) do
      # school : répond à cycle ; lookup : Entities::Catalog::TaxonomyLookup.
      # → Result(Placement) | failure(:invalid, errors: { level_slug: [...] } | { series_slug: [...] })
      def self.resolve(school:, level_slug:, series_slug:, lookup:)
        level = lookup.level(level_slug)
        return invalid(:level_slug, :inclusion) if level.nil?
        return invalid(:level_slug, :not_allowed) if school.cycle == "first" && !level.first_cycle?

        series = lookup.find_series(series_slug)
        error = series_error(series_slug, series, level, lookup)
        return invalid(:series_slug, error) if error

        ::Shared::Result.success(new(level:, series:))
      end

      # Une classe d'un niveau à séries en porte une, ouverte à ce niveau ; un niveau sans série n'en prend pas.
      def self.series_error(slug, series, level, lookup)
        return (:blank if lookup.series_for(level.id).any?) if slug.nil?
        return :inclusion if series.nil?

        :not_allowed unless lookup.pair?(level.id, series.id)
      end
      private_class_method :series_error

      def self.invalid(field, kind) = ::Shared::Result.failure(:invalid, errors: { field => [ kind ] })
      private_class_method :invalid

      def ids = { level_id: level.id, series_id: series&.id }
    end
  end
end

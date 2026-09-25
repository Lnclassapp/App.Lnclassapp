# 🧠 DOMAINE · Entities::Classroom::DefaultClassroomPlan
# Rôle : nombre de classes générées par niveau et série à la création d'un établissement
# ADR  : 0030, 0034, 0039
module Entities
  module Classroom
    module DefaultClassroomPlan
      PLAN = {
        "public" => { "6eme" => 4, "5eme" => 4, "4eme" => 10, "3eme" => 10, "2nde" => { per_series: 6 },
                      "1ere" => { per_series: 6 }, "tle" => { "c" => 2, "d" => 6, "a1" => 3, "a2" => 2 } },
        "private" => { "6eme" => 2, "5eme" => 2, "4eme" => 4, "3eme" => 4, "2nde" => { per_series: 3 },
                       "1ere" => { per_series: 3 }, "tle" => { "c" => 1, "d" => 3, "a1" => 2, "a2" => 2 } }
      }.freeze

      # rows : [{ name:, level_id:, series_id: }] ; skipped : { levels: ["1ere"], series: ["tle/c"] }, les niveaux
      # et les couples niveau/série absents du référentiel, sautés et comptés dans le rapport d'import.
      Generation = Data.define(:rows, :skipped)

      # Un établissement mixed suit le barème private, comme dans l'ancien.
      def self.for(school_type) = PLAN.fetch(school_type == "public" ? "public" : "private")

      # school : répond à school_type et cycle (entité ou ligne insérée) ; lookup : Entities::Catalog::TaxonomyLookup
      def self.rows_for(school:, lookup:)
        rows = []
        skipped = { levels: [], series: [] }
        self.for(school.school_type).each do |level_slug, config|
          level = lookup.level(level_slug)
          next skipped[:levels] << level_slug if level.nil?
          next if school.cycle == "first" && !level.first_cycle?

          counts = counts_for(level, config, lookup, skipped)
          counts.each { |series, count| rows.concat(rows_of(level, series, count)) }
        end
        Generation.new(rows:, skipped:)
      end

      # → [[série ou nil, nombre de classes]]
      def self.counts_for(level, config, lookup, skipped)
        return [ [ nil, config ] ] if config.is_a?(Integer)
        return per_series(level, config[:per_series], lookup, skipped) if config.key?(:per_series)

        config.filter_map do |series_slug, count|
          series = lookup.find_series(series_slug)
          next [ series, count ] if series && lookup.pair?(level.id, series.id)

          skipped[:series] << "#{level.slug}/#{series_slug}"
          nil
        end
      end
      private_class_method :counts_for

      # « par série » : chaque série liée au niveau ; un niveau sans série est sauté et compté.
      def self.per_series(level, count, lookup, skipped)
        linked = lookup.series_for(level.id)
        skipped[:levels] << level.slug if linked.empty?
        linked.map { |series| [ series, count ] }
      end
      private_class_method :per_series

      # Noms toujours espacés : « 6ème 1 », « Tle D 3 », « Tle A1 2 ».
      def self.rows_of(level, series, count)
        prefix = [ level.name, series&.name ].compact.join(" ")
        (1..count).map { |n| { name: "#{prefix} #{n}", level_id: level.id, series_id: series&.id } }
      end
      private_class_method :rows_of
    end
  end
end

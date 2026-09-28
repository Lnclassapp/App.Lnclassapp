# 🧠 DOMAINE · Entities::Classroom::DefaultClassroomPlan
# Rôle : classes générées pour un établissement, fonction pure du référentiel et du barème reçu ; feuille de l'écran du barème
# ADR  : 0030, 0034, 0039, 0058
module Entities
  module Classroom
    module DefaultClassroomPlan
      # rows : [{ name:, level_id:, series_id: }] ; skipped : { levels: ["1ere"], series: ["tle/e"] }, les niveaux et les
      # couples niveau/série sans nombre au barème (ou niveau du second cycle sans série), sautés et comptés au rapport.
      Generation = Data.define(:rows, :skipped)

      # Une ligne du barème : un niveau du premier cycle (series nil), un couple niveau × série liée, ou un niveau du
      # second cycle sans série (unlinked). counts : { "public" => Integer | nil, "private" => Integer | nil }.
      Line = Data.define(:level, :series, :counts) do
        def unlinked? = !level.first_cycle? && series.nil?
        def undefined? = !unlinked? && counts.values.any?(&:nil?)
        def name = [ level.name, series&.name ].compact.join(" ")
        def key = [ level.slug, series&.slug ].compact.join("_")
        def level_slug = level.slug
        def series_slug = series&.slug
      end

      # totals : { "public" => { "first" => collège, "both" => lycée }, "private" => … }
      Sheet = Data.define(:lines, :totals) do
        def undefined_count = lines.count(&:undefined?)
      end

      CYCLES = %w[first both].freeze
      # Établissement type d'un total.
      Target = Data.define(:school_type, :cycle)
      private_constant :Target

      # school : répond à school_type et cycle (entité ou ligne insérée) ; lookup : Entities::Catalog::TaxonomyLookup ;
      # plan : ClassroomPlan. Un collège (cycle first) ne prend que les niveaux du premier cycle.
      def self.rows_for(school:, lookup:, plan:)
        rows = []
        skipped = { levels: [], series: [] }
        slots(lookup).each do |level, series|
          next if school.cycle == "first" && !level.first_cycle?
          next skipped[:levels] << level.slug if !level.first_cycle? && series.nil?

          count = plan.count(school_type: school.school_type, level_id: level.id, series_id: series&.id)
          next skip(level, series, skipped) if count.nil?

          rows.concat(rows_of(level, series, count))
        end
        Generation.new(rows:, skipped:)
      end

      # La feuille de l'écran : les lignes du référentiel avec leurs deux nombres, et le total par établissement.
      def self.sheet(plan:, lookup:)
        lines = slots(lookup).map do |level, series|
          counts = ClassroomPlan::SCHOOL_TYPES.to_h { [ it, plan.count(school_type: it, level_id: level.id, series_id: series&.id) ] }
          Line.new(level:, series:, counts:)
        end
        totals = ClassroomPlan::SCHOOL_TYPES.to_h do |school_type|
          [ school_type, CYCLES.to_h { |cycle| [ cycle, rows_for(school: Target.new(school_type:, cycle:), lookup:, plan:).rows.size ] } ]
        end
        Sheet.new(lines:, totals:)
      end

      # → [[niveau, série | nil]], par position : un niveau du premier cycle, chaque série liée d'un niveau du second,
      # ou [niveau, nil] pour un niveau du second cycle sans série.
      def self.slots(lookup)
        lookup.levels.sort_by(&:position).flat_map do |level|
          next [ [ level, nil ] ] if level.first_cycle?

          linked = lookup.series_for(level.id)
          linked.empty? ? [ [ level, nil ] ] : linked.map { [ level, it ] }
        end
      end
      private_class_method :slots

      def self.skip(level, series, skipped)
        return skipped[:levels] << level.slug if series.nil?

        skipped[:series] << "#{level.slug}/#{series.slug}"
      end
      private_class_method :skip

      # Noms toujours espacés : « 6ème 1 », « Tle D 3 », « Tle A1 2 ».
      def self.rows_of(level, series, count)
        prefix = [ level.name, series&.name ].compact.join(" ")
        (1..count).map { |n| { name: "#{prefix} #{n}", level_id: level.id, series_id: series&.id } }
      end
      private_class_method :rows_of
    end
  end
end

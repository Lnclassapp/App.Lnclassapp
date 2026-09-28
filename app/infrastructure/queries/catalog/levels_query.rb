# 🔌 INFRA · Queries::Catalog::LevelsQuery
# Rôle : niveaux de l'écran de l'équipe, par position : séries, usage (classes, cours), présence au barème des classes
# ADR  : 0026, 0030, 0034, 0036, 0058
module Queries
  module Catalog
    class LevelsQuery
      Row = Data.define(:slug, :name, :position, :cycle, :series_names, :classrooms_count, :courses_count,
                        :generates_classrooms)

      def call = rows(Orm::Level.all)

      # → Row | nil
      def find(slug:) = rows(Orm::Level.where(slug:)).first

      private

      # Une requête par table : niveaux, séries liées, classes, cours, barème.
      def rows(scope)
        levels = scope.order(:position).pluck(:id, :slug, :name, :position, :cycle)
        ids = levels.map(&:first)
        series = series_names(ids)
        classrooms = Orm::Classroom.where(level_id: ids).group(:level_id).count
        courses = Orm::Course.where(level_id: ids).group(:level_id).count
        planned = planned_level_ids(ids)

        levels.map do |id, slug, name, position, cycle|
          Row.new(slug:, name:, position:, cycle:, series_names: series.fetch(id, []),
                  classrooms_count: classrooms.fetch(id, 0), courses_count: courses.fetch(id, 0),
                  generates_classrooms: planned.include?(id))
        end
      end

      # Niveaux qui ont au moins un nombre positif au barème (ADR-0058), public ou privé : au premier cycle, ou pour un
      # couple encore lié (un couple délié garde son nombre, sans effet).
      def planned_level_ids(level_ids)
        linked = Orm::LevelSeries.where("level_series.level_id = classroom_plan_entries.level_id")
                                 .where("level_series.series_id = classroom_plan_entries.series_id")
        Orm::ClassroomPlanEntry.where(level_id: level_ids).where("count > 0")
                               .where("classroom_plan_entries.series_id IS NULL OR EXISTS (#{linked.select(1).to_sql})")
                               .distinct.pluck(:level_id).to_set
      end

      def series_names(level_ids)
        Orm::LevelSeries.joins(:series).where(level_id: level_ids).order("series.name").pluck(:level_id, "series.name")
                        .each_with_object({}) { |(level_id, name), grouped| (grouped[level_id] ||= []) << name }
      end
    end
  end
end

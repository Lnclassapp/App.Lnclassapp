# 🔌 INFRA · Queries::School::LevelClassroomsQuery
# Rôle : lignes du bloc « Classes par niveau » de la fiche : nombre de classes de l'année par niveau/série, et la dernière
# ADR  : 0030, 0041, 0059 · UDR : 0046
module Queries
  module School
    class LevelClassroomsQuery
      Block = Data.define(:school_public_id, :school_status, :rows)
      # key : « 6eme », « tle-d » ; open : couple offert à l'établissement (« + » possible) ; last_classroom : celle que « − » retire.
      Row = Data.define(:key, :label, :level_slug, :series_slug, :count, :last_classroom, :open)
      LastClassroom = Data.define(:public_id, :name)
      Level = Data.define(:id, :slug, :name, :position, :cycle)
      Series = Data.define(:id, :slug, :name)

      # Lignes : couples ouverts au référentiel pour le cycle de l'établissement (un niveau sans série liée en est un), plus
      # ceux qui ont des classes de l'année sans être ouverts : la somme des lignes est le total de la fiche. → Block | nil
      def call(public_id:, school_year: Entities::Classroom::SchoolYear.current(Date.current))
        school_id, status, cycle = Orm::School.where(public_id:).pick(:id, :status, :cycle)
        return if school_id.nil?

        levels = Orm::Level.order(:position).pluck(:id, :slug, :name, :position, :cycle).map { Level.new(*it) }.index_by(&:id)
        series = Orm::Series.pluck(:id, :slug, :name).map { Series.new(*it) }.index_by(&:id)
        classrooms = Orm::Classroom.where(school_id:, school_year:).pluck(:level_id, :series_id, :public_id, :name)
                                   .group_by { it.first(2) }
        open = open_pairs(levels.values, series, cycle)

        pairs = (open + classrooms.keys).uniq.sort_by { |level_id, series_id| [ levels[level_id].position, series[series_id]&.name.to_s ] }
        rows = pairs.map { |pair| row(levels[pair.first], series[pair.last], classrooms.fetch(pair, []), open.include?(pair)) }
        Block.new(school_public_id: public_id, school_status: status, rows:)
      end

      private

      # → [[level_id, series_id | nil]], comme « Ajouter une classe » : un collège n'a que le premier cycle.
      def open_pairs(levels, series, cycle)
        linked = Orm::LevelSeries.pluck(:level_id, :series_id).group_by(&:first)
        levels.select { cycle != "first" || it.cycle == "first" }.flat_map do |level|
          ids = linked.fetch(level.id, []).map(&:last)
          ids.empty? ? [ [ level.id, nil ] ] : ids.map { [ level.id, it ] }
        end
      end

      def row(level, series, classrooms, open)
        last_name = Entities::Classroom::ClassroomNumbering.last(names: classrooms.map(&:last))
        last = classrooms.find { it.last == last_name }
        Row.new(key: [ level.slug, series&.slug ].compact.join("-"),
                label: Entities::Classroom::ClassroomNumbering.prefix(level_name: level.name, series_name: series&.name),
                level_slug: level.slug, series_slug: series&.slug, count: classrooms.size,
                last_classroom: last && LastClassroom.new(public_id: last[2], name: last[3]), open:)
      end
    end
  end
end

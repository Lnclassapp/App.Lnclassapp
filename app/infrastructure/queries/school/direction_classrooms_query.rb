# 🔌 INFRA · Queries::School::DirectionClassroomsQuery
# Rôle : classes actives de l'année d'un établissement, par niveau, avec effectif et plafond (filtres, choix d'une classe)
# ADR  : 0041, 0066 · UDR : 0052
module Queries
  module School
    class DirectionClassroomsQuery
      Level = Data.define(:name, :classrooms)
      Row = Data.define(:public_id, :name, :level_name, :students_count, :capacity)

      COLUMNS = %w[classrooms.id classrooms.public_id classrooms.name classrooms.max_students levels.name levels.position
                   series.name].freeze

      # Triées par niveau, série, puis numéro (« 6ème 2 » avant « 6ème 10 »). → [Level]
      def call(school_id:, school_year: current_year)
        rows = scope(school_id, school_year).pluck(*COLUMNS)
        counts = Orm::ClassroomStudent.where(classroom_id: rows.map(&:first), left_at: nil).group(:classroom_id).count

        rows.sort_by { |_, _, name, _, _, position, series| [ position, series.to_s, name[/\d+\z/].to_i, name ] }
            .chunk_while { |left, right| left[5] == right[5] }
            .map { |group| Level.new(name: group.first[4], classrooms: group.map { row(it, counts) }) }
      end

      # Une classe d'un filtre ou d'un choix est-elle une classe active de l'année de cet établissement ? → Boolean
      def includes?(school_id:, public_id:, school_year: current_year)
        scope(school_id, school_year).exists?(public_id:)
      end

      private

      def current_year = Entities::Classroom::SchoolYear.current(Date.current)

      def scope(school_id, school_year)
        Orm::Classroom.joins(:level).left_joins(:series).where(school_id:, school_year:, status: "active")
      end

      def row(values, counts)
        id, public_id, name, capacity, level_name = values
        Row.new(public_id:, name:, level_name:, students_count: counts.fetch(id, 0), capacity:)
      end
    end
  end
end

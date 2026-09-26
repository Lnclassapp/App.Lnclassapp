# 🔌 INFRA · Queries::Catalog::TeamHomeQuery
# Rôle : accueil équipe (TR-09, CA-25) : compteurs, niveaux et leurs séries, derniers cours, exercices et imports
# ADR  : 0026, 0034, 0035, 0039, 0041 · UDR : 0018
module Queries
  module Catalog
    class TeamHomeQuery
      Row = Data.define(:drenas_count, :schools_count, :classrooms_count, :levels, :series_count, :materials_count,
                        :recent_courses, :recent_exercises, :recent_imports)
      LevelRow = Data.define(:slug, :name, :series_names)
      CourseRow = Data.define(:slug, :name, :status, :level_name, :material_name, :material_category, :updated_at)
      ExerciseRow = Data.define(:public_id, :title, :status, :essential_name, :updated_at)
      # filename : nil tant que le fichier source n'est pas attaché.
      ImportRow = Data.define(:public_id, :kind, :status, :filename, :updated_at)

      RECENT = 5

      # Lecture directe des tables, sans cache : un compteur suit la dernière création de l'équipe (CA-25).
      # today : fixe l'année scolaire des classes comptées (ADR-0041).
      def call(today: Date.current)
        Row.new(drenas_count: Orm::Drena.count, schools_count: Orm::School.count,
                classrooms_count: Orm::Classroom.where(status: "active", school_year: Entities::Classroom::SchoolYear.current(today)).count,
                levels:, series_count: Orm::Series.count, materials_count: Orm::Material.count,
                recent_courses:, recent_exercises:, recent_imports:)
      end

      # Les trois listes récentes sont aussi lues seules, par le frame différé de l'activité.
      def recent_courses
        Orm::Course.joins(:level, :material).order(updated_at: :desc, id: :desc).limit(RECENT)
                   .pluck(:slug, :name, :status, "levels.name", "materials.name", "materials.category", :updated_at)
                   .map { |values| CourseRow.new(*values) }
      end

      def recent_exercises
        Orm::Exercise.joins(:essential).order(updated_at: :desc, id: :desc).limit(RECENT)
                     .pluck(:public_id, :title, :status, "essentials.name", :updated_at)
                     .map { |values| ExerciseRow.new(*values) }
      end

      def recent_imports
        Orm::ImportReport.left_joins(source_attachment: :blob).order(updated_at: :desc, id: :desc).limit(RECENT)
                         .pluck(:public_id, :kind, :status, "active_storage_blobs.filename", :updated_at)
                         .map { |values| ImportRow.new(*values) }
      end

      private

      def levels
        series = Orm::LevelSeries.joins(:series).order("series.name").pluck(:level_id, "series.name")
                                 .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
        Orm::Level.order(:position).pluck(:id, :slug, :name).map do |id, slug, name|
          LevelRow.new(slug:, name:, series_names: series.fetch(id, []))
        end
      end
    end
  end
end

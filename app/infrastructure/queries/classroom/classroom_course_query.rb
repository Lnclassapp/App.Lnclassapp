# 🔌 INFRA · Queries::Classroom::ClassroomCourseQuery
# Rôle : un cours publié vu depuis une classe (CL-11) : ses fiches publiées et leur nombre d'exercices ; rien ne s'y assigne
# ADR  : 0026, 0035, 0048, 0072 · UDR : 0028, 0062
module Queries
  module Classroom
    class ClassroomCourseQuery
      # ADR-0072 §4.1 : ni le cours ni ses fiches ne s'assignent ; aucune assignation n'est lue ici.
      Row = Data.define(:classroom_public_id, :classroom_name, :course, :essentials)
      CourseRow = Data.define(:slug, :name, :subtitle, :level_name, :series_name, :material_name, :material_category)
      EssentialRow = Data.define(:slug, :name, :subtitle, :exercises_count)

      COURSE_COLUMNS = %w[courses.id courses.slug courses.name courses.subtitle levels.name series.name materials.name
                          materials.category].freeze

      # → Row | nil (classe inconnue, cours inconnu ou non publié)
      def call(classroom_public_id:, course_slug:)
        classroom_id, classroom_name = Orm::Classroom.where(public_id: classroom_public_id).pick(:id, :name)
        return if classroom_id.nil?

        course_id, *course = Orm::Course.joins(:level, :material).left_joins(:series)
                                        .where(slug: course_slug, status: "published").pick(*COURSE_COLUMNS)
        return if course_id.nil?

        essentials = Orm::Essential.where(course_id:, status: "published").order(:position).pluck(:id, :slug, :name, :subtitle)
        Row.new(classroom_public_id:, classroom_name:, course: CourseRow.new(*course), essentials: essential_rows(essentials))
      end

      private

      def essential_rows(essentials)
        exercises = Orm::Exercise.where(essential_id: essentials.map(&:first), status: "published").group(:essential_id).count
        essentials.map do |id, slug, name, subtitle|
          EssentialRow.new(slug:, name:, subtitle:, exercises_count: exercises.fetch(id, 0))
        end
      end
    end
  end
end

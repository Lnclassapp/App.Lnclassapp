# 🔌 INFRA · Queries::Classroom::ClassroomCourseQuery
# Rôle : un cours publié vu depuis une classe (CL-11) : son en-tête ; les sections de la leçon sont lues par leurs propres queries
# ADR  : 0026, 0035, 0048, 0072, 0113 · UDR : 0028, 0062, 0139
module Queries
  module Classroom
    class ClassroomCourseQuery
      # ADR-0072 §4.1 : le cours ne s'assigne pas ; aucune assignation n'est lue ici.
      Row = Data.define(:classroom_public_id, :classroom_name, :course)
      CourseRow = Data.define(:slug, :name, :subtitle, :level_name, :series_name, :material_name, :material_category)

      COURSE_COLUMNS = %w[courses.slug courses.name courses.subtitle levels.name series.name materials.name
                          materials.category].freeze

      # → Row | nil (classe inconnue, cours inconnu ou non publié)
      def call(classroom_public_id:, course_slug:)
        classroom_id, classroom_name = Orm::Classroom.where(public_id: classroom_public_id).pick(:id, :name)
        return if classroom_id.nil?

        course = Orm::Course.joins(:level, :material).left_joins(:series)
                            .where(slug: course_slug, status: "published").pick(*COURSE_COLUMNS)
        return if course.nil?

        Row.new(classroom_public_id:, classroom_name:, course: CourseRow.new(*course))
      end
    end
  end
end

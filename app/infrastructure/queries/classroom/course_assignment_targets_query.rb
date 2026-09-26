# 🔌 INFRA · Queries::Classroom::CourseAssignmentTargetsQuery
# Rôle : assigner un cours depuis sa page (CA-27) : le cours publié, et les classes actives de l'enseignant avec leur assignation
# ADR  : 0026, 0035, 0048 · UDR : 0030
module Queries
  module Classroom
    class CourseAssignmentTargetsQuery
      Row = Data.define(:course, :classrooms)
      CourseRow = Data.define(:slug, :name, :subtitle, :level_name, :series_name, :material_name, :material_category)
      # assignment_public_id : l'assignation active de ce cours à cette classe, ou nil.
      ClassroomRow = Data.define(:public_id, :name, :level_name, :series_name, :school_name, :assignment_public_id)

      COURSE_COLUMNS = %w[courses.id courses.slug courses.name courses.subtitle levels.name series.name materials.name
                          materials.category].freeze
      CLASSROOM_COLUMNS = %w[classrooms.id classrooms.public_id classrooms.name levels.name series.name schools.name
                             levels.position].freeze

      # → Row | nil (cours inconnu ou non publié)
      def call(teacher_id:, course_slug:)
        course_id, *course = Orm::Course.joins(:level, :material).left_joins(:series)
                                        .where(slug: course_slug, status: "published").pick(*COURSE_COLUMNS)
        return if course_id.nil?

        Row.new(course: CourseRow.new(*course), classrooms: classrooms(teacher_id, course_id))
      end

      private

      def classrooms(teacher_id, course_id)
        rows = Orm::Classroom.joins(:level, :school, :teacher_classrooms).left_joins(:series)
                             .where(teacher_classrooms: { teacher_id: }, status: "active").pluck(*CLASSROOM_COLUMNS)
        active = Orm::ClassroomAssignment.where(classroom_id: rows.map(&:first), assignable_type: "Course",
                                                assignable_id: course_id, status: "active").pluck(:classroom_id, :public_id).to_h

        rows.sort_by { |*, name, _, _, _, position| [ position, natural_key(name) ] }
            .map { |id, *values, _position| ClassroomRow.new(*values, active[id]) }
      end

      # « 6ème 2 » avant « 6ème 10 », comme l'accueil enseignant (TeacherHomeQuery).
      def natural_key(name)
        name.scan(/\d+|\D+/).map { |part| part.match?(/\A\d/) ? [ 0, part.to_i ] : [ 1, part ] }
      end
    end
  end
end

# 🔌 INFRA · Queries::Classroom::ClassroomCourseQuery
# Rôle : un cours publié vu depuis une classe (CL-11) : ses fiches publiées, et l'assignation active du cours et de chaque fiche
# ADR  : 0026, 0035, 0048 · UDR : 0028
module Queries
  module Classroom
    class ClassroomCourseQuery
      Row = Data.define(:classroom_public_id, :classroom_name, :course, :essentials)
      # assignment_public_id : l'assignation active à cette classe, ou nil.
      CourseRow = Data.define(:slug, :name, :subtitle, :level_name, :series_name, :material_name, :material_category,
                              :assignment_public_id)
      EssentialRow = Data.define(:slug, :name, :subtitle, :exercises_count, :assignment_public_id)

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
        active = active_assignments(classroom_id, course_id, essentials.map(&:first))
        Row.new(classroom_public_id:, classroom_name:, course: course_row(course, active[[ "Course", course_id ]]),
                essentials: essential_rows(essentials, active))
      end

      private

      # { [type, id] => public_id } ; le type est lu avec l'identifiant : un exercice n'est jamais pris pour une fiche.
      def active_assignments(classroom_id, course_id, essential_ids)
        scope = Orm::ClassroomAssignment.where(classroom_id:, status: "active")
        scope.where(assignable_type: "Course", assignable_id: course_id)
             .or(scope.where(assignable_type: "Essential", assignable_id: essential_ids))
             .pluck(:assignable_type, :assignable_id, :public_id)
             .to_h { |type, id, public_id| [ [ type, id ], public_id ] }
      end

      def course_row(values, assignment_public_id)
        slug, name, subtitle, level_name, series_name, material_name, material_category = values
        CourseRow.new(slug:, name:, subtitle:, level_name:, series_name:, material_name:, material_category:, assignment_public_id:)
      end

      def essential_rows(essentials, active)
        exercises = Orm::Exercise.where(essential_id: essentials.map(&:first), status: "published").group(:essential_id).count
        essentials.map do |id, slug, name, subtitle|
          EssentialRow.new(slug:, name:, subtitle:, exercises_count: exercises.fetch(id, 0),
                           assignment_public_id: active[[ "Essential", id ]])
        end
      end
    end
  end
end

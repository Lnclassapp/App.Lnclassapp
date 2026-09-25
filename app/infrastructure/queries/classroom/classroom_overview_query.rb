# 🔌 INFRA · Queries::Classroom::ClassroomOverviewQuery
# Rôle : corps de la page d'une classe (CL-10) : cours assignés actifs et publiés ; élèves présents, seulement si show_roster
# ADR  : 0026, 0028, 0048 · UDR : 0027
module Queries
  module Classroom
    class ClassroomOverviewQuery
      # students : nil sans show_roster (ReadClassroomPolicy) — la liste nominative n'est alors même pas lue.
      Overview = Data.define(:courses, :students)
      CourseRow = Data.define(:slug, :name, :subtitle, :level_name, :series_name, :material_name, :material_category,
                              :essentials_count)
      StudentRow = Data.define(:public_id, :display_name, :contact, :last_score_percent)

      COURSE_COLUMNS = %w[courses.id courses.slug courses.name courses.subtitle levels.name series.name materials.name
                          materials.category].freeze
      STUDENT_COLUMNS = %w[users.id users.public_id users.first_name users.last_name users.contact].freeze

      # → Overview | nil
      def call(public_id:, show_roster:)
        id = Orm::Classroom.where(public_id:).pick(:id)
        return if id.nil?

        Overview.new(courses: courses(id), students: (students(id) if show_roster))
      end

      private

      # Seules les lignes Course comptent : une fiche ou un exercice assigné ne se précharge pas ici (CS#B8).
      def courses(classroom_id)
        assigned = Orm::ClassroomAssignment.where(classroom_id:, assignable_type: "Course", status: "active").select(:assignable_id)
        rows = Orm::Course.joins(:level, :material).left_joins(:series).where(id: assigned, status: "published")
                          .order(:name).pluck(*COURSE_COLUMNS)
        essentials = Orm::Essential.where(course_id: rows.map(&:first), status: "published").group(:course_id).count

        rows.map do |id, slug, name, subtitle, level_name, series_name, material_name, material_category|
          CourseRow.new(slug:, name:, subtitle:, level_name:, series_name:, material_name:, material_category:,
                        essentials_count: essentials.fetch(id, 0))
        end
      end

      def students(classroom_id)
        rows = Orm::ClassroomStudent.joins(:student).where(classroom_id:, left_at: nil)
                                    .order("users.last_name", "users.first_name").pluck(*STUDENT_COLUMNS)
        scores = last_scores(rows.map(&:first))

        rows.map do |id, public_id, first_name, last_name, contact|
          StudentRow.new(public_id:, display_name: "#{first_name} #{last_name}", contact:, last_score_percent: scores[id])
        end
      end

      # Score de la dernière session terminée de chaque élève, en une requête.
      def last_scores(student_ids)
        Orm::ExerciseSession.where(student_id: student_ids, status: "completed").order(:student_id, completed_at: :desc)
                            .pluck(Arel.sql("DISTINCT ON (student_id) student_id"), :score_percent).to_h
      end
    end
  end
end

# 🔌 INFRA · Queries::Classroom::TeacherHomeQuery
# Rôle : accueil enseignant (TR-05) : école principale, matière, classes déclarées de l'année avec effectif, assignations, score
# ADR  : 0026, 0041, 0048 · UDR : 0026
module Queries
  module Classroom
    class TeacherHomeQuery
      Row = Data.define(:school_name, :material_name, :material_category, :classrooms)
      # average_score_percent : moyenne des sessions terminées des élèves présents, dans la matière de l'enseignant ; nil sans session.
      ClassroomRow = Data.define(:public_id, :name, :level_name, :active_students_count, :active_assignments_count,
                                 :average_score_percent)

      COLUMNS = [ "classrooms.id", "classrooms.public_id", "classrooms.name", "levels.name", "levels.position" ].freeze

      # today : fixe l'année scolaire (ADR-0041).
      def call(teacher_id:, today: Date.current)
        material_id, material_name, material_category =
          Orm::TeacherProfile.joins(:material).where(user_id: teacher_id).pick(:material_id, "materials.name", "materials.category")

        Row.new(school_name: Orm::TeacherSchool.joins(:school).where(teacher_id:, primary: true).pick("schools.name"),
                material_name:, material_category:, classrooms: classrooms(teacher_id, material_id, today))
      end

      private

      def classrooms(teacher_id, material_id, today)
        rows = Orm::Classroom.joins(:level, :teacher_classrooms)
                             .where(teacher_classrooms: { teacher_id: }, status: "active",
                                    school_year: Entities::Classroom::SchoolYear.current(today))
                             .pluck(*COLUMNS)
        ids = rows.map(&:first)
        members = Orm::ClassroomStudent.where(classroom_id: ids, left_at: nil).pluck(:classroom_id, :student_id)
        assignments = Orm::ClassroomAssignment.where(classroom_id: ids, status: "active").group(:classroom_id).count
        scores = average_scores(members, material_id)

        rows.sort_by { |*, name, _, position| [ position, natural_key(name) ] }.map do |id, public_id, name, level_name|
          ClassroomRow.new(public_id:, name:, level_name:, active_students_count: members.count { it.first == id },
                           active_assignments_count: assignments.fetch(id, 0), average_score_percent: scores[id])
        end
      end

      # Une requête pour tous les élèves, puis l'agrégat par classe en mémoire : total des scores ÷ nombre de sessions.
      def average_scores(members, material_id)
        by_student = Orm::ExerciseSession.joins(exercise: { essential: :course })
                                         .where(student_id: members.map(&:last), status: "completed", courses: { material_id: })
                                         .group(:student_id).pluck(:student_id, Arel.sql("SUM(score_percent)"), Arel.sql("COUNT(*)"))
                                         .to_h { |student_id, sum, count| [ student_id, [ sum, count ] ] }
        members.group_by(&:first).filter_map do |classroom_id, pairs|
          totals = pairs.filter_map { |_, student_id| by_student[student_id] }
          [ classroom_id, totals.sum(&:first).fdiv(totals.sum(&:last)).round ] if totals.any?
        end.to_h
      end

      # « 6ème 2 » avant « 6ème 10 », comme la déclaration des classes (TeachingSelectionQuery).
      def natural_key(name)
        name.scan(/\d+|\D+/).map { |part| part.match?(/\A\d/) ? [ 0, part.to_i ] : [ 1, part ] }
      end
    end
  end
end

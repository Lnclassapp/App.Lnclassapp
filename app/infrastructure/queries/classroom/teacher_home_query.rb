# 🔌 INFRA · Queries::Classroom::TeacherHomeQuery
# Rôle : accueil enseignant (TR-05) : école, matière, classes déclarées de l'année (effectif, assignations, score), niveaux enseignés
# ADR  : 0026, 0041, 0048 · UDR : 0026, 0069
module Queries
  module Classroom
    class TeacherHomeQuery
      # material_slug : slug figé de la matière, qui choisit l'illustration des bulles « Cours » (UDR-0069 §3.3).
      Row = Data.define(:school_name, :material_name, :material_category, :material_slug, :classrooms, :course_levels)
      # average_score_percent : moyenne des sessions terminées des élèves présents, dans la matière de l'enseignant ; nil sans session.
      ClassroomRow = Data.define(:public_id, :name, :level_name, :active_students_count, :active_assignments_count,
                                 :average_score_percent)
      # Une bulle « Cours » : label « 3ème », « Tle D » ; series_slug nil pour une classe sans série.
      CourseLevel = Data.define(:level_slug, :series_slug, :label)

      COLUMNS = [ "classrooms.id", "classrooms.public_id", "classrooms.name", "levels.name", "levels.position", "levels.slug",
                  "series.slug", "series.name" ].freeze

      # today : fixe l'année scolaire (ADR-0041).
      def call(teacher_id:, today: Date.current)
        material_id, material_name, material_category, material_slug =
          Orm::TeacherProfile.joins(:material).where(user_id: teacher_id)
                             .pick(:material_id, "materials.name", "materials.category", "materials.slug")
        rows = classroom_rows(teacher_id, today)

        Row.new(school_name: Orm::TeacherSchool.joins(:school).where(teacher_id:, primary: true).pick("schools.name"),
                material_name:, material_category:, material_slug:, classrooms: classrooms(rows, material_id),
                course_levels: course_levels(rows))
      end

      private

      # Les niveaux enseignés se lisent sur les mêmes lignes que les classes : aucune requête de plus (UDR-0069 §3.3).
      def classroom_rows(teacher_id, today)
        Orm::Classroom.joins(:level, :teacher_classrooms).left_joins(:series)
                      .where(teacher_classrooms: { teacher_id: }, status: "active",
                             school_year: Entities::Classroom::SchoolYear.current(today))
                      .pluck(*COLUMNS)
      end

      def classrooms(rows, material_id)
        ids = rows.map(&:first)
        members = Orm::ClassroomStudent.where(classroom_id: ids, left_at: nil).pluck(:classroom_id, :student_id)
        assignments = Orm::ClassroomAssignment.where(classroom_id: ids, status: "active").group(:classroom_id).count
        scores = average_scores(members, material_id)

        rows.sort_by { |_, _, name, _, position| [ position, natural_key(name) ] }.map do |id, public_id, name, level_name|
          ClassroomRow.new(public_id:, name:, level_name:, active_students_count: members.count { it.first == id },
                           active_assignments_count: assignments.fetch(id, 0), average_score_percent: scores[id])
        end
      end

      # Un couple (niveau, série) par bulle : « 3ème 1 » et « 3ème 2 » n'en font qu'une. Tri : position du niveau, puis
      # la classe sans série, puis le nom de la série.
      def course_levels(rows)
        rows.map { it.last(5) }.uniq # levels.name, levels.position, levels.slug, series.slug, series.name
            .sort_by { |_, position, _, _, series_name| [ position, series_name ? 1 : 0, series_name.to_s ] }
            .map do |level_name, _, level_slug, series_slug, series_name|
              CourseLevel.new(level_slug:, series_slug:, label: [ level_name, series_name ].compact.join(" "))
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

# 🔌 INFRA · Queries::Classroom::TeacherHomeQuery
# Rôle : accueil enseignant (TR-05) : établissement courant, ses matières dans cet établissement, classes déclarées de l'année, niveaux enseignés
# ADR  : 0026, 0041, 0048, 0094, 0103 · UDR : 0026, 0069, 0098, 0126 (§3.2 à §3.4)
module Queries
  module Classroom
    class TeacherHomeQuery
      # materials : [Identity::TeacherMaterialsQuery::MaterialTag] de l'établissement courant, dans l'ordre (ADR-0103) ; le slug
      # d'une matière seule choisit l'illustration des bulles « Cours » (UDR-0069 §3.3, UDR-0126 §3.3).
      Row = Data.define(:school_name, :materials, :classrooms, :course_levels) do
        def several_materials? = materials.size > 1
      end
      # average_score_percent : moyenne des sessions terminées des élèves présents, dans ses matières (UDR-0126 §3.4) ; nil sans session.
      ClassroomRow = Data.define(:public_id, :name, :level_name, :active_students_count, :active_assignments_count,
                                 :average_score_percent)
      # Une bulle « Cours » : label « 3ème », « Tle D » ; series_slug nil pour une classe sans série.
      CourseLevel = Data.define(:level_slug, :series_slug, :label)

      COLUMNS = [ "classrooms.id", "classrooms.public_id", "classrooms.name", "levels.name", "levels.position", "levels.slug",
                  "series.slug", "series.name" ].freeze

      # school_id : l'établissement courant (actor.school_id, ADR-0094 §4.6) ; today : fixe l'année scolaire (ADR-0041).
      def call(teacher_id:, school_id:, today: Date.current)
        materials = Queries::Identity::TeacherMaterialsQuery.new.tags_for(teacher_ids: [ teacher_id ], school_id:).fetch(teacher_id)
        rows = classroom_rows(teacher_id, school_id, today)

        Row.new(school_name: Orm::School.where(id: school_id).pick(:name), materials:,
                classrooms: classrooms(rows, materials.map(&:id)), course_levels: course_levels(rows))
      end

      private

      # Les niveaux enseignés se lisent sur les mêmes lignes que les classes : aucune requête de plus (UDR-0069 §3.3).
      def classroom_rows(teacher_id, school_id, today)
        Orm::Classroom.joins(:level, :teacher_classrooms).left_joins(:series)
                      .where(teacher_classrooms: { teacher_id: }, school_id:, status: "active",
                             school_year: Entities::Classroom::SchoolYear.current(today))
                      .pluck(*COLUMNS)
      end

      def classrooms(rows, material_ids)
        ids = rows.map(&:first)
        members = Orm::ClassroomStudent.where(classroom_id: ids, left_at: nil).pluck(:classroom_id, :student_id)
        assignments = Orm::ClassroomAssignment.where(classroom_id: ids, status: "active").group(:classroom_id).count
        scores = average_scores(members, material_ids)

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
      def average_scores(members, material_ids)
        by_student = Orm::ExerciseSession.joins(exercise: { essential: :course })
                                         .where(student_id: members.map(&:last), status: "completed", courses: { material_id: material_ids })
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

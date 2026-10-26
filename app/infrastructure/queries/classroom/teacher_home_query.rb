# 🔌 INFRA · Queries::Classroom::TeacherHomeQuery
# Rôle : accueil enseignant (TR-05) : établissement courant et son sigle, ses matières, classes déclarées de l'année (code, badges), niveaux enseignés
# ADR  : 0026, 0041, 0048, 0094, 0103 · UDR : 0026, 0069, 0098, 0126 (§3.2 à §3.4), écrans enseignant (§3.2 badges, §3.3 carte de classe)
module Queries
  module Classroom
    class TeacherHomeQuery
      # materials : [Identity::TeacherMaterialsQuery::MaterialTag] de l'établissement courant, dans l'ordre (ADR-0103) ; le slug
      # d'une matière seule choisit l'illustration des bulles « Cours » (UDR-0069 §3.3, UDR-0126 §3.3).
      Row = Data.define(:school_name, :school_sigle, :materials, :classrooms, :course_levels) do
        def several_materials? = materials.size > 1
      end
      # join_code : le code de la classe, brut (6 caractères) ; badge_counts : { bronze:, silver:, gold:, diamond: } d'élèves,
      # chaque élève présent une fois, « Pas encore » non compté (UDR enseignant §3.2).
      ClassroomRow = Data.define(:public_id, :name, :level_name, :active_students_count, :active_assignments_count,
                                 :join_code, :badge_counts)
      # Une bulle « Cours » : label « 3ème », « Tle D » ; series_slug nil pour une classe sans série.
      CourseLevel = Data.define(:level_slug, :series_slug, :label)

      COLUMNS = [ "classrooms.id", "classrooms.public_id", "classrooms.name", "levels.name", "levels.position", "levels.slug",
                  "series.slug", "series.name", "classrooms.join_code" ].freeze

      # school_id : l'établissement courant (actor.school_id, ADR-0094 §4.6) ; today : fixe l'année scolaire (ADR-0041).
      def call(teacher_id:, school_id:, today: Date.current)
        materials = Queries::Identity::TeacherMaterialsQuery.new.tags_for(teacher_ids: [ teacher_id ], school_id:).fetch(teacher_id)
        rows = classroom_rows(teacher_id, school_id, today)

        school_name, school_sigle = Orm::School.where(id: school_id).pick(:name, :sigle)
        Row.new(school_name:, school_sigle: school_sigle.presence, materials:, classrooms: classrooms(rows),
                course_levels: course_levels(rows))
      end

      private

      # Les niveaux enseignés se lisent sur les mêmes lignes que les classes : aucune requête de plus (UDR-0069 §3.3).
      def classroom_rows(teacher_id, school_id, today)
        Orm::Classroom.joins(:level, :teacher_classrooms).left_joins(:series)
                      .where(teacher_classrooms: { teacher_id: }, school_id:, status: "active",
                             school_year: Entities::Classroom::SchoolYear.current(today))
                      .pluck(*COLUMNS)
      end

      def classrooms(rows)
        ids = rows.map(&:first)
        members = Orm::ClassroomStudent.where(classroom_id: ids, left_at: nil).pluck(:classroom_id, :student_id)
        assignments = Orm::ClassroomAssignment.where(classroom_id: ids, status: "active").group(:classroom_id).count
        badges = badge_counts(members)

        rows.sort_by { |_, _, name, _, position| [ position, natural_key(name) ] }.map do |id, public_id, name, level_name, *, join_code|
          ClassroomRow.new(public_id:, name:, level_name:, active_students_count: members.count { it.first == id },
                           active_assignments_count: assignments.fetch(id, 0), join_code:, badge_counts: badges[id])
        end
      end

      # Un couple (niveau, série) par bulle : « 3ème 1 » et « 3ème 2 » n'en font qu'une. Tri : position du niveau, puis
      # la classe sans série, puis le nom de la série.
      def course_levels(rows)
        rows.map { it[3, 5] }.uniq # levels.name, levels.position, levels.slug, series.slug, series.name
            .sort_by { |_, position, _, _, series_name| [ position, series_name ? 1 : 0, series_name.to_s ] }
            .map do |level_name, _, level_slug, series_slug, series_name|
              CourseLevel.new(level_slug:, series_slug:, label: [ level_name, series_name ].compact.join(" "))
            end
      end

      # Une requête pour tous les élèves présents, puis l'agrégat en mémoire (UDR enseignant §3.2) : la meilleure session
      # terminée de l'élève à chaque assignation active de sa classe, rangée par `Grading.class_badge_for`.
      # → { classroom_id => { bronze:, silver:, gold:, diamond: } }
      def badge_counts(members)
        counts = Hash.new { |hash, classroom_id| hash[classroom_id] = Entities::Assessment::Grading::BADGE_ORDER.index_with(0) }
        return counts if members.empty?

        bests = Orm::ExerciseSession.joins(:classroom_assignment)
                                    .where(status: "completed", student_id: members.map(&:last).uniq,
                                           classroom_assignments: { classroom_id: members.map(&:first).uniq, status: "active" })
                                    .group(:student_id, :classroom_assignment_id, "classroom_assignments.classroom_id")
                                    .pluck(:student_id, "classroom_assignments.classroom_id", Arel.sql("MAX(exercise_sessions.score_percent)"))
        scores = bests.group_by { |student_id, classroom_id, _| [ classroom_id, student_id ] }
        members.each do |classroom_id, student_id|
          best = scores.fetch([ classroom_id, student_id ], []).map(&:last)
          badge = Entities::Assessment::Grading.class_badge_for(scores: best, all_perfect: best.all? { Entities::Assessment::Grading.perfect?(it) })
          counts[classroom_id][badge] += 1 if badge
        end
        counts
      end

      # « 6ème 2 » avant « 6ème 10 », comme la déclaration des classes (TeachingSelectionQuery).
      def natural_key(name)
        name.scan(/\d+|\D+/).map { |part| part.match?(/\A\d/) ? [ 0, part.to_i ] : [ 1, part ] }
      end
    end
  end
end

# 🔌 INFRA · Queries::Classroom::TeacherHomeQuery
# Rôle : accueil enseignant (TR-05) : établissement courant et son sigle, ses matières, classes déclarées de l'année (élèves, exercices en cours, retard), « À suivre », niveaux enseignés
# ADR  : 0026, 0041, 0048, 0094, 0103 · UDR : 0026, 0069, 0098, 0126 (§3.2 à §3.4), écrans enseignant (§3.3), accueil-enseignant-actions (§3.1, §3.2)
module Queries
  module Classroom
    class TeacherHomeQuery
      # materials : [Identity::TeacherMaterialsQuery::MaterialTag] de l'établissement courant, dans l'ordre (ADR-0103) ; le slug
      # d'une matière seule choisit l'illustration des bulles « Cours » (UDR-0069 §3.3, UDR-0126 §3.3).
      Row = Data.define(:school_name, :school_sigle, :materials, :classrooms, :course_levels) do
        def several_materials? = materials.size > 1

        # UDR accueil-enseignant-actions §3.1 : les classes à suivre, la plus urgente d'abord (FollowUpPriority).
        def to_follow
          classrooms.each_with_index.select { |classroom, _| classroom.to_follow? }
                    .sort_by { |classroom, position| classroom.rank(position) }.map(&:first)
        end

        # Les autres, dans l'ordre des classes.
        def others = classrooms.reject(&:to_follow?)
      end
      # late_students_count : élèves présents qui n'ont pas terminé au moins une assignation active échue (avant today) ;
      # late_assignments_count : ces assignations échues qu'au moins un élève présent n'a pas terminées.
      ClassroomRow = Data.define(:public_id, :name, :level_name, :active_students_count, :active_assignments_count,
                                 :late_students_count, :late_assignments_count) do
        def to_follow?
          Entities::Classroom::FollowUpPriority.to_follow?(students: active_students_count, late_students: late_students_count,
                                                          active_assignments: active_assignments_count)
        end

        def rank(position)
          Entities::Classroom::FollowUpPriority.rank(late_students: late_students_count, active_assignments: active_assignments_count, position:)
        end
      end
      # Une bulle « Cours » : label « 3ème », « Tle D » ; short_label « 3e », « Tle D » (le rond, UDR accueil-enseignant-actions
      # §3.2) ; series_slug nil pour une classe sans série.
      CourseLevel = Data.define(:level_slug, :series_slug, :label, :short_label)

      COLUMNS = [ "classrooms.id", "classrooms.public_id", "classrooms.name", "levels.name", "levels.position", "levels.slug",
                  "series.slug", "series.name" ].freeze

      # school_id : l'établissement courant (actor.school_id, ADR-0094 §4.6) ; today : fixe l'année scolaire (ADR-0041).
      def call(teacher_id:, school_id:, today: Date.current)
        materials = Queries::Identity::TeacherMaterialsQuery.new.tags_for(teacher_ids: [ teacher_id ], school_id:).fetch(teacher_id)
        rows = classroom_rows(teacher_id, school_id, today)

        school_name, school_sigle = Orm::School.where(id: school_id).pick(:name, :sigle)
        Row.new(school_name:, school_sigle: school_sigle.presence, materials:, classrooms: classrooms(rows, today),
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

      def classrooms(rows, today)
        ids = rows.map(&:first)
        members = Orm::ClassroomStudent.where(classroom_id: ids, left_at: nil).pluck(:classroom_id, :student_id)
        assignments = Orm::ClassroomAssignment.where(classroom_id: ids, status: "active").pluck(:id, :classroom_id, :due_on)
        late = lateness(members, assignments, today)

        rows.sort_by { |_, _, name, _, position| [ position, natural_key(name) ] }.map do |id, public_id, name, level_name, *|
          late_students, late_assignments = late.fetch(id, [ 0, 0 ])
          ClassroomRow.new(public_id:, name:, level_name:, active_students_count: members.count { it.first == id },
                           active_assignments_count: assignments.count { it[1] == id },
                           late_students_count: late_students, late_assignments_count: late_assignments)
        end
      end

      # Une requête de plus : les couples (assignation échue, élève) terminés. Le reste en mémoire.
      # → { classroom_id => [élèves en retard, assignations en retard] }
      def lateness(members, assignments, today)
        overdue = assignments.select { |_, _, due_on| due_on && due_on < today }
        return {} if overdue.empty? || members.empty?

        done = Orm::ExerciseSession.where(status: "completed", classroom_assignment_id: overdue.map(&:first))
                                   .distinct.pluck(:classroom_assignment_id, :student_id).to_set
        students = members.group_by(&:first).transform_values { it.map(&:last) }
        overdue.group_by { it[1] }.to_h do |classroom_id, due|
          missing = due.to_h { |id, *| [ id, students.fetch(classroom_id, []).reject { done.include?([ id, it ]) } ] }
          [ classroom_id, [ missing.values.flatten.uniq.size, missing.count { |_, late| late.any? } ] ]
        end
      end

      # Un couple (niveau, série) par bulle : « 3ème 1 » et « 3ème 2 » n'en font qu'une. Tri : position du niveau, puis
      # la classe sans série, puis le nom de la série.
      def course_levels(rows)
        rows.map { it[3, 5] }.uniq # levels.name, levels.position, levels.slug, series.slug, series.name
            .sort_by { |_, position, _, _, series_name| [ position, series_name ? 1 : 0, series_name.to_s ] }
            .map do |level_name, _, level_slug, series_slug, series_name|
              CourseLevel.new(level_slug:, series_slug:, label: [ level_name, series_name ].compact.join(" "),
                              short_label: Entities::Classroom::LevelShortName.for(level: level_name, series: series_name))
            end
      end

      # « 6ème 2 » avant « 6ème 10 », comme la déclaration des classes (TeachingSelectionQuery).
      def natural_key(name)
        name.scan(/\d+|\D+/).map { |part| part.match?(/\A\d/) ? [ 0, part.to_i ] : [ 1, part ] }
      end
    end
  end
end

# 🔌 INFRA · Queries::Classroom::CatalogAssignmentTargetsQuery
# Rôle : les classes de l'enseignant où assigner un exercice depuis le catalogue (niveau et série du cours), l'assignation
#        active de chaque exercice dans chacune, et si la modale des jours doit s'ouvrir — deux requêtes au plus
# ADR  : 0026, 0035 (amendement du 2026-10-01), 0041, 0072 · UDR : 0062 (§3.4), 0069 (§3.8)
module Queries
  module Classroom
    class CatalogAssignmentTargetsQuery
      # scope_label : « Tle D », « 3ème » ; states : { [classroom_public_id, exercise_public_id] => State }, actives seulement.
      Targets = Data.define(:scope_label, :classrooms, :states)
      # needs_session_days : l'enseignant n'a aucun jour de séance pour cette classe ; « Assigner » ouvre la modale (ADR-0072 §4.2).
      Target = Data.define(:public_id, :name, :needs_session_days)
      State = Data.define(:assignment_public_id, :due_on)

      COURSE_COLUMNS = %w[courses.level_id courses.series_id levels.name series.name].freeze

      # Sous-requête corrélée, sans paramètre : la déclaration lue (teacher_classrooms) n'a encore aucun jour de séance.
      NEEDS_SESSION_DAYS = Arel.sql(<<~SQL.squish)
        NOT EXISTS (SELECT 1 FROM classroom_session_days
                    WHERE classroom_session_days.teacher_id = teacher_classrooms.teacher_id
                      AND classroom_session_days.classroom_id = classrooms.id)
      SQL

      # Les pages du catalogue ne lisent que le slug du cours et le public_id des exercices : la query les prend tels quels.
      # today : fixe l'année scolaire (ADR-0041). → Targets | nil (cours inconnu)
      def call(teacher_id:, course_slug:, exercise_public_ids:, today: Date.current)
        level_id, series_id, level_name, series_name =
          Orm::Course.joins(:level).left_joins(:series).where(slug: course_slug).pick(*COURSE_COLUMNS)
        return if level_id.nil?

        rows = rows(teacher_id, level_id, series_id, exercise_public_ids, today)
        Targets.new(scope_label: [ level_name, series_name ].compact.join(" "), classrooms: classrooms(rows), states: states(rows))
      end

      private

      # Une ligne par (classe, assignation active d'un exercice demandé), une seule ligne sans assignation : la règle de
      # l'élève (LevelAudience) — le niveau du cours et, si le cours a une série, cette série ; sans série, toutes.
      def rows(teacher_id, level_id, series_id, exercise_public_ids, today)
        scope = Orm::Classroom.joins(:teacher_classrooms)
                              .where(teacher_classrooms: { teacher_id: }, status: "active", level_id:,
                                     school_year: Entities::Classroom::SchoolYear.current(today))
        scope = scope.where(series_id:) if series_id
        scope.joins("LEFT OUTER JOIN (#{active_assignments(exercise_public_ids).to_sql}) states " \
                    "ON states.classroom_id = classrooms.id")
             .pluck("classrooms.public_id", "classrooms.name", NEEDS_SESSION_DAYS,
                    "states.exercise_public_id", "states.public_id", "states.due_on")
      end

      def active_assignments(exercise_public_ids)
        Orm::ClassroomAssignment.joins("INNER JOIN exercises ON exercises.id = classroom_assignments.assignable_id")
                                .where(status: "active", assignable_type: "Exercise", exercises: { public_id: exercise_public_ids })
                                .select("classroom_assignments.classroom_id", "classroom_assignments.public_id",
                                        "classroom_assignments.due_on", "exercises.public_id AS exercise_public_id")
      end

      def classrooms(rows)
        rows.map { |public_id, name, needs_session_days| Target.new(public_id:, name:, needs_session_days:) }
            .uniq.sort_by { natural_key(it.name) }
      end

      def states(rows)
        rows.each_with_object({}) do |(classroom_public_id, _, _, exercise_public_id, public_id, due_on), states|
          next if exercise_public_id.nil?

          states[[ classroom_public_id, exercise_public_id ]] = State.new(assignment_public_id: public_id, due_on:)
        end
      end

      # « Tle D 2 » avant « Tle D 10 », comme l'accueil enseignant (TeacherHomeQuery).
      def natural_key(name)
        name.scan(/\d+|\D+/).map { |part| part.match?(/\A\d/) ? [ 0, part.to_i ] : [ 1, part ] }
      end
    end
  end
end

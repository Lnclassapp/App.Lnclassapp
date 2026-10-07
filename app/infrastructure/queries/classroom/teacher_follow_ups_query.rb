# 🔌 INFRA · Queries::Classroom::TeacherFollowUpsQuery
# Rôle : « Activités » de l'accueil enseignant : les exercices assignés de ses classes, dans sa matière, à suivre cette semaine
# ADR  : 0026, 0041, 0067, 0072, 0079 · UDR : 0077 §3.1 · nombre fixe de requêtes, quel que soit le nombre de classes
module Queries
  module Classroom
    class TeacherFollowUpsQuery
      # pending : élèves présents qui ne l'ont pas encore fait ; present : élèves présents de la classe.
      Row = Data.define(:public_id, :exercise_title, :classroom_public_id, :classroom_name, :due_on, :pending, :present)

      # Échéance dans les 7 prochains jours, ou passée depuis 14 jours au plus (UDR-0077 §3.1, memo).
      AHEAD = 7
      BEHIND = 14

      COLUMNS = %w[classroom_assignments.id classroom_assignments.public_id exercises.title classrooms.id classrooms.public_id
                   classrooms.name classroom_assignments.due_on].freeze

      # today : fixe l'année scolaire (ADR-0041) et la fenêtre d'échéance. → [Row], échéance croissante, puis classe.
      def call(teacher_id:, today: Date.current)
        rows = assignments(teacher_id, today)
        return [] if rows.empty?

        present = present_counts(rows.map { it[3] }.uniq)
        done = done_counts(rows.map(&:first))
        rows.filter_map do |id, public_id, exercise_title, classroom_id, classroom_public_id, classroom_name, due_on|
          count = present.fetch(classroom_id, 0)
          pending = count - done.fetch(id, 0)
          Row.new(public_id:, exercise_title:, classroom_public_id:, classroom_name:, due_on:, pending:, present: count) if pending.positive?
        end
      end

      private

      # Les assignations actives des classes actives de l'année où il enseigne, d'un exercice de sa matière.
      def assignments(teacher_id, today)
        Orm::ClassroomAssignment.joins(:classroom).joins(AssignmentFollowUpQuery::EXERCISE)
                                .where(status: "active", due_on: (today - BEHIND)..(today + AHEAD),
                                       classrooms: { status: "active", school_year: Entities::Classroom::SchoolYear.current(today),
                                                     id: Orm::TeacherClassroom.where(teacher_id:).select(:classroom_id) },
                                       courses: { material_id: Orm::TeacherProfile.where(user_id: teacher_id).select(:material_id) })
                                .order(:due_on, "classrooms.name", :id)
                                .pluck(*COLUMNS)
      end

      # Présent : adhésion non quittée, compte non anonymisé (AssignmentFollowUpQuery.present_students, ADR-0072 §4.4).
      def present_counts(classroom_ids)
        Orm::ClassroomStudent.joins(:student).where(classroom_id: classroom_ids, left_at: nil, users: { anonymized_at: nil })
                             .group(:classroom_id).count
      end

      # Fait : un élève présent de la classe de l'assignation, avec une session terminée qui lui est rattachée, standard
      # ou de remédiation (ADR-0048, ADR-0079 §4.1).
      def done_counts(assignment_ids)
        Orm::ExerciseSession.joins("JOIN classroom_assignments ON classroom_assignments.id = exercise_sessions.classroom_assignment_id")
                            .joins("JOIN classroom_students ON classroom_students.classroom_id = classroom_assignments.classroom_id " \
                                   "AND classroom_students.student_id = exercise_sessions.student_id " \
                                   "AND classroom_students.left_at IS NULL")
                            .joins("JOIN users ON users.id = exercise_sessions.student_id AND users.anonymized_at IS NULL")
                            .where(classroom_assignment_id: assignment_ids, status: "completed")
                            .group(:classroom_assignment_id).distinct.count(:student_id)
      end
    end
  end
end

# 🔌 INFRA · Queries::Classroom::AssignmentFollowUpQuery
# Rôle : suivi d'un exercice assigné : faits (remédiation comprise), dont en retard, pas encore faits ; retards et restants nommés
# ADR  : 0026, 0048, 0072, 0079 · UDR : 0062, 0072 · appelée après FollowAssignmentPolicy seulement : elle nomme des élèves
module Queries
  module Classroom
    class AssignmentFollowUpQuery
      Counts = Data.define(:done, :late, :pending)
      # assigned_on, done_on : dates locales d'Abidjan.
      Row = Data.define(:public_id, :exercise_public_id, :exercise_title, :material_name, :material_category, :due_on,
                        :assigned_on, :counts, :late_students, :pending_students)
      LateStudent = Data.define(:display_name, :done_on)
      PendingStudent = Data.define(:display_name)

      # ADR-0072 §4.1 : une assignation ne porte plus qu'un exercice.
      EXERCISE = "JOIN exercises ON exercises.id = classroom_assignments.assignable_id " \
                 "AND classroom_assignments.assignable_type = 'Exercise' " \
                 "JOIN essentials ON essentials.id = exercises.essential_id JOIN courses ON courses.id = essentials.course_id " \
                 "JOIN materials ON materials.id = courses.material_id".freeze
      COLUMNS = %w[classroom_assignments.id classroom_assignments.classroom_id classroom_assignments.public_id exercises.public_id
                   exercises.title materials.name materials.category classroom_assignments.due_on
                   classroom_assignments.assigned_at].freeze

      # → Row | nil (assignation inconnue, archivée ou d'une autre classe)
      def call(classroom_public_id:, public_id:)
        id, classroom_id, public_id, exercise_public_id, exercise_title, material_name, material_category, due_on, assigned_at =
          Orm::ClassroomAssignment.joins(:classroom).joins(EXERCISE)
                                  .where(public_id:, status: "active", classrooms: { public_id: classroom_public_id }).pick(*COLUMNS)
        return if id.nil?

        Row.new(public_id:, exercise_public_id:, exercise_title:, material_name:, material_category:, due_on:,
                assigned_on: assigned_at.in_time_zone.to_date,
                counts: self.class.counts(classroom_id:, assignment_ids: [ id ]).fetch(id),
                late_students: late_students(classroom_id, id, due_on), pending_students: pending_students(classroom_id, id))
      end

      # { assignment_id => Counts } pour des assignations d'une même classe : deux requêtes, quel que soit leur nombre.
      # Fait : un élève présent avec une session terminée rattachée à l'assignation (ADR-0048), standard ou de remédiation
      # (ADR-0079 §4.1) ; en retard : la date locale de la première, quel que soit son kind, est postérieure à due_on (le
      # jour même est à l'heure) ; sans échéance, jamais en retard.
      def self.counts(classroom_id:, assignment_ids:)
        return {} if assignment_ids.empty?

        present = present_students(classroom_id).count
        handed = Orm::ClassroomAssignment.joins("JOIN (#{first_done(classroom_id, assignment_ids).to_sql}) firsts " \
                                                "ON firsts.assignment_id = classroom_assignments.id")
                                         .group(:id)
                                         .pluck(:id, Arel.sql("COUNT(*)"),
                                                Arel.sql("COUNT(*) FILTER (WHERE firsts.done_on > classroom_assignments.due_on)"))
                                         .to_h { |id, done, late| [ id, [ done, late ] ] }
        assignment_ids.to_h do |id|
          done, late = handed.fetch(id, [ 0, 0 ])
          [ id, Counts.new(done:, late:, pending: present - done) ]
        end
      end

      # Présent : adhésion non quittée, compte non anonymisé (ADR-0072 §4.4).
      def self.present_students(classroom_id)
        Orm::ClassroomStudent.joins(:student).where(classroom_id:, left_at: nil, users: { anonymized_at: nil })
      end

      # Une ligne par élève présent et assignation : la date locale de sa première session rendue (done_on), standard ou de
      # remédiation : une remédiation sur l'exercice assigné, c'est faire cet exercice (ADR-0079 §4.1).
      # Index : index_exercise_sessions_on_classroom_assignment_id (le partiel handed_in ne couvre que kind = 'standard').
      def self.first_done(classroom_id, assignment_ids)
        local_date = "((exercise_sessions.completed_at AT TIME ZONE 'UTC') AT TIME ZONE " \
                     "#{Orm::ExerciseSession.connection.quote(Time.zone.tzinfo.name)})::date"
        Orm::ExerciseSession.where(classroom_assignment_id: assignment_ids, status: "completed",
                                   student_id: present_students(classroom_id).select(:student_id))
                            .group(:classroom_assignment_id, :student_id)
                            .select("exercise_sessions.classroom_assignment_id AS assignment_id", :student_id,
                                    "MIN(#{local_date}) AS done_on")
      end

      private

      def late_students(classroom_id, id, due_on)
        return [] if due_on.nil?

        Orm::User.joins("JOIN (#{self.class.first_done(classroom_id, [ id ]).to_sql}) firsts ON firsts.student_id = users.id")
                 .where("firsts.done_on > ?", due_on).order(:last_name, :first_name, :id)
                 .pluck(:first_name, :last_name, "firsts.done_on")
                 .map { |first_name, last_name, done_on| LateStudent.new(display_name: "#{first_name} #{last_name}", done_on:) }
      end

      # Présents sans session faite sur l'assignation, une session seulement commencée comprise (ADR-0079 §4.8).
      def pending_students(classroom_id, id)
        Orm::User.where(id: self.class.present_students(classroom_id).select(:student_id))
                 .joins("LEFT JOIN (#{self.class.first_done(classroom_id, [ id ]).to_sql}) firsts ON firsts.student_id = users.id")
                 .where(firsts: { student_id: nil }).order(:last_name, :first_name, :id)
                 .pluck(:first_name, :last_name)
                 .map { |first_name, last_name| PendingStudent.new(display_name: "#{first_name} #{last_name}") }
      end
    end
  end
end

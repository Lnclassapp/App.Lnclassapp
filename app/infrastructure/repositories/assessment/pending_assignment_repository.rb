# 🔌 INFRA · Repositories::Assessment::PendingAssignmentRepository
# Rôle : les exercices que l'élève doit encore rendre à son enseignant (assignation active de sa classe principale, sans copie rendue)
# ADR  : XXXX-sujets-de-devoir-et-verification-sur-la-feuille (§4), 0048
module Repositories
  module Assessment
    class PendingAssignmentRepository
      include Ports::Assessment::PendingAssignmentRepositoryPort

      def pending_exercise_public_ids(student_id:, exercise_public_ids:)
        return Set.new if exercise_public_ids.empty?

        classrooms = Orm::ClassroomStudent.joins(:classroom)
                                          .where(student_id:, primary: true, left_at: nil, classrooms: { status: "active" })
                                          .select(:classroom_id)
        assignments = Orm::ClassroomAssignment
                      .joins("INNER JOIN exercises ON exercises.id = classroom_assignments.assignable_id")
                      .where(classroom_id: classrooms, status: "active", assignable_type: "Exercise", exercises: { public_id: exercise_public_ids })
                      .pluck("classroom_assignments.id", "exercises.public_id")
        return Set.new if assignments.empty?

        handed_in = Orm::ExerciseSession.where(student_id:, status: "completed", classroom_assignment_id: assignments.map(&:first))
                                        .pluck(:classroom_assignment_id).to_set
        assignments.reject { |id, _| handed_in.include?(id) }.to_set { |_, public_id| public_id }
      end
    end
  end
end

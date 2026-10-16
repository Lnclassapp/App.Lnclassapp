# 🔌 INFRA · Queries::Classroom::StudentFileQuery
# Rôle : fiche d'un élève présent dans sa classe (CL-13, AS-24) : en-tête, chiffres et badges de la classe, exercices assignés, « fait seul »
# ADR  : 0026, 0072, 0079, 0083 (§4.4 bis), 0089 (§4.2), 0097 · UDR : 0107 · après ReadClassroomPolicy (show_roster) seulement
module Queries
  module Classroom
    class StudentFileQuery
      # ADR-0097 §4.4 : la fenêtre de « fait seul » de la fiche, aujourd'hui compris, et ses lignes au plus.
      SELF_PRACTICE_DAYS = 30
      SELF_PRACTICE_LIMIT = 20
      # contact : masqué (ADR-0083 §4.4 bis) ; joined_via : Entities::Classroom::StudentArrivalChannel.
      File = Data.define(:student, :counts, :badge_counts, :assignments, :self_practice, :self_practice_total)
      Student = Data.define(:public_id, :display_name, :contact, :photo_version, :joined_at, :joined_via, :newcomer)
      Counts = Data.define(:done, :late, :pending, :assigned)
      # status : :done, :late (rendu en retard), :pending, :overdue (pas fait, échéance passée).
      # best, category, trend, sessions_count, best_session_public_id : nil sans session faite ; trend nil à une session.
      AssignmentRow = Data.define(:public_id, :exercise_title, :material_name, :material_category, :due_on, :status,
                                  :done_on, :best, :category, :trend, :sessions_count, :best_session_public_id)
      SelfPracticeRow = Data.define(:session_public_id, :exercise_title, :material_name, :material_category,
                                    :score_percent, :completed_at)

      # today : date d'Abidjan (Time.zone), jamais Date.today. → File | nil (élève absent de la classe : 404)
      def call(classroom_public_id:, student_public_id:, today: Time.zone.today) = raise NotImplementedError
    end
  end
end

# 🔌 INFRA · Queries::Classroom::StudentFileQuery
# Rôle : fiche d'un élève présent dans sa classe (CL-13, AS-24) : en-tête, chiffres et badges de la classe, exercices assignés, « fait seul »
# ADR  : 0026, 0072, 0079, 0083 (§4.4 bis), 0089 (§4.2), 0097 · UDR : enseignant §3.2, 0107 · après ReadClassroomPolicy (show_roster) seulement
module Queries
  module Classroom
    class StudentFileQuery
      Comprehension = Entities::Assessment::Comprehension
      Grading = Entities::Assessment::Grading

      # ADR-0097 §4.4 : la fenêtre de « fait seul » de la fiche, aujourd'hui compris, et ses lignes au plus.
      SELF_PRACTICE_DAYS = 30
      SELF_PRACTICE_LIMIT = 20
      # contact : masqué (ADR-0083 §4.4 bis) ; joined_via : Entities::Classroom::StudentArrivalChannel.
      # class_grade, class_badge : « Moyenne 14/20 · Or », la règle de la liste de la classe (Grading.class_badge_for) ; nil sans exercice fait.
      File = Data.define(:student, :counts, :badge_counts, :assignments, :self_practice, :self_practice_total, :class_grade,
                         :class_badge)
      Student = Data.define(:public_id, :display_name, :contact, :photo_version, :joined_at, :joined_via, :newcomer)
      Counts = Data.define(:done, :late, :pending, :assigned)
      # status : :done, :late (rendu en retard), :pending, :overdue (pas fait, échéance passée).
      # best, category, trend, sessions_count, best_session_public_id : nil sans session faite ; trend nil à une session.
      AssignmentRow = Data.define(:public_id, :exercise_title, :material_name, :material_category, :due_on, :status,
                                  :done_on, :best, :category, :trend, :sessions_count, :best_session_public_id)
      SelfPracticeRow = Data.define(:session_public_id, :exercise_title, :material_name, :material_category,
                                    :score_percent, :completed_at)

      STUDENT_COLUMNS = %w[users.id users.public_id users.first_name users.last_name users.contact classroom_students.joined_at
                           classroom_students.joined_via].freeze
      SELF_PRACTICE_COLUMNS = %w[exercise_sessions.public_id exercises.title materials.name materials.category
                                 exercise_sessions.score_percent exercise_sessions.completed_at].freeze
      MATERIAL = "JOIN exercises ON exercises.id = exercise_sessions.exercise_id " \
                 "JOIN courses ON courses.id = exercises.course_id " \
                 "JOIN materials ON materials.id = courses.material_id".freeze

      # today : date d'Abidjan (Time.zone), jamais Date.today. → File | nil (élève absent de la classe : 404)
      # Présent : l'ADR-0072 §4.4 (adhésion non quittée, compte non anonymisé) ; parti, anonymisé, d'ailleurs ou inconnu : nil.
      def call(classroom_public_id:, student_public_id:, today: Time.zone.today)
        classroom_id = Orm::Classroom.where(public_id: classroom_public_id).pick(:id)
        return if classroom_id.nil?

        row = AssignmentFollowUpQuery.present_students(classroom_id).where(users: { public_id: student_public_id })
                                     .pick(*STUDENT_COLUMNS)
        return if row.nil?

        build(classroom_id, row, today)
      end

      private

      def build(classroom_id, (id, public_id, first_name, last_name, contact, joined_at, joined_via), today)
        assignments = assignments(classroom_id, id, today)
        practice = self_practice(id, today)
        File.new(student: Student.new(public_id:, display_name: "#{first_name} #{last_name}", contact: Entities::Identity::Contact.mask(contact),
                                      photo_version: Queries::Identity::PhotoVersions.for(user_ids: [ id ])[id], joined_at:,
                                      joined_via:, newcomer: joined_at > Time.current - ClassroomOverviewQuery::NEW_FOR),
                 counts: counts(assignments), badge_counts: badge_counts(assignments), assignments:,
                 self_practice: practice.order(completed_at: :desc, id: :desc).limit(SELF_PRACTICE_LIMIT)
                                        .pluck(*SELF_PRACTICE_COLUMNS).map { SelfPracticeRow.new(*it) },
                 self_practice_total: practice.count, **standing(assignments))
      end

      # UDR enseignant §3.2 : la moyenne des meilleurs scores sur 20 et le badge de classe qu'elle donne.
      def standing(assignments)
        bests = assignments.filter_map(&:best)
        return { class_grade: nil, class_badge: nil } if bests.empty?

        { class_grade: Entities::Classroom::RosterGrade.grade_for(bests.sum.fdiv(bests.size)),
          class_badge: Grading.class_badge_for(scores: bests, all_perfect: bests.all? { Grading.perfect?(it) }) }
      end

      # ADR-0097 §4.3 : les assignations actives, dans l'ordre de la page de la classe (UDR-0062 §3.4) ; les scores et la
      # première session faite de l'élève par les définitions du suivi (AssignmentScores, AssignmentFollowUpQuery.first_done).
      def assignments(classroom_id, student_id, today)
        rows = Orm::ClassroomAssignment.joins(AssignmentFollowUpQuery::EXERCISE).where(classroom_id:, status: "active")
                                       .order(Arel.sql("classroom_assignments.due_on ASC NULLS LAST"), assigned_at: :desc, id: :desc)
                                       .pluck(*ClassroomOverviewQuery::ASSIGNMENT_COLUMNS)
        ids = rows.map(&:first)
        scores = Queries::Assessment::AssignmentScores.for(classroom_id:, assignment_ids: ids, student_id:)
                                                      .transform_values(&:first)
        sessions = Orm::ExerciseSession.where(id: scores.values.map(&:best_session_id)).pluck(:id, :public_id).to_h
        firsts = ids.empty? ? {} : AssignmentFollowUpQuery.first_done(classroom_id, ids).where(student_id:)
                                                          .to_h { [ it.assignment_id, it.done_on ] }
        rows.map do |id, public_id, exercise_title, material_name, material_category, due_on|
          assignment_row(scores[id], firsts[id], sessions, today, public_id:, exercise_title:, material_name:, material_category:,
                                                                         due_on:)
        end
      end

      def assignment_row(student_scores, done_on, sessions, today, due_on:, **)
        return AssignmentRow.new(**, due_on:, status: due_on && due_on < today ? :overdue : :pending, done_on: nil, best: nil,
                                 category: nil, trend: nil, sessions_count: nil, best_session_public_id: nil) if student_scores.nil?

        best = student_scores.scores.max
        AssignmentRow.new(**, due_on:, status: due_on && done_on > due_on ? :late : :done, done_on:, best:,
                          category: Comprehension.category_for(best), trend: Comprehension.trend_for(student_scores.scores),
                          sessions_count: student_scores.scores.size,
                          best_session_public_id: sessions.fetch(student_scores.best_session_id))
      end

      def counts(assignments)
        statuses = assignments.map(&:status).tally
        done = statuses.fetch(:done, 0) + statuses.fetch(:late, 0)
        Counts.new(done:, late: statuses.fetch(:late, 0), pending: assignments.size - done, assigned: assignments.size)
      end

      # ADR-0097 §4.5 : un palier par exercice fait, d'après son meilleur score ici ; exercise_badges n'est pas lue.
      def badge_counts(assignments)
        Grading::BADGE_ORDER.index_with { 0 }.merge(assignments.filter_map { Grading.badge_for(it.best) if it.best }.tally)
      end

      # ADR-0089 §4.2 sur SELF_PRACTICE_DAYS jours : la définition de la liste des élèves, une seule fois.
      def self_practice(student_id, today)
        ClassroomOverviewQuery.self_practice(today, days: SELF_PRACTICE_DAYS).where(student_id:).joins(MATERIAL)
      end
    end
  end
end

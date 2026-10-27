# 🔌 INFRA · Queries::Classroom::TeacherFollowUpsQuery
# Rôle : « Cette semaine » et « Historique » de l'accueil enseignant : les exercices assignés de ses classes, dans ses matières, sans recouvrement
# ADR  : 0026, 0041, 0067, 0072, 0079, 0094, 0103 · UDR : 0077 §3.1, 0126 §3.4, écrans enseignant §3.3 · nombre fixe de requêtes, quel que soit le nombre de classes
module Queries
  module Classroom
    class TeacherFollowUpsQuery
      # pending : élèves présents qui ne l'ont pas encore fait ; done : ceux qui l'ont fait ; present : élèves présents de la classe ;
      # average_percent : moyenne de la classe des meilleurs scores, nil si personne ne l'a fait ; material_* : la matière de
      # l'exercice (badge de l'enseignant de plusieurs matières, UDR-0126 §3.4 ; rond de la ligne par son slug).
      Row = Data.define(:public_id, :exercise_title, :classroom_public_id, :classroom_name, :due_on, :pending, :done, :present,
                        :average_percent, :material_name, :material_slug, :material_category)
      # week : « Cette semaine », échéance croissante ; history : « Historique », échéance décroissante.
      Result = Data.define(:week, :history)

      # Cette semaine : échéance dans les 7 prochains jours (demain compris), faite par tous ou non ; ou passée depuis 14 jours au
      # plus (aujourd'hui compris), avec au moins un élève qui ne l'a pas fait ; sans échéance (d'avant le pilote), tant qu'un
      # élève ne l'a pas fait. Historique : échue (aujourd'hui compris) depuis 30 jours au plus et pas dans « Cette semaine »
      # (UDR enseignant §3.3) : une assignation n'est jamais dans les deux.
      AHEAD = 7
      BEHIND = 14
      HISTORY = 30

      COLUMNS = %w[classroom_assignments.id classroom_assignments.public_id exercises.title classrooms.id classrooms.public_id
                   classrooms.name classroom_assignments.due_on materials.name materials.slug materials.category].freeze

      # school_id : l'établissement courant (ADR-0094 §4.6) ; today : fixe l'année scolaire (ADR-0041) et les fenêtres d'échéance.
      # → Result
      def call(teacher_id:, school_id:, today: Date.current)
        rows = assignments(teacher_id, school_id, today)
        return Result.new(week: [], history: []) if rows.empty?

        present = present_counts(rows.map { it[3] }.uniq)
        bests = best_scores(rows.map(&:first))
        week = []
        history = []
        rows.each do |id, public_id, exercise_title, classroom_id, classroom_public_id, classroom_name, due_on, *material|
          count = present.fetch(classroom_id, 0)
          next unless count.positive?

          scores = bests.fetch(id, [])
          row = Row.new(public_id:, exercise_title:, classroom_public_id:, classroom_name:, due_on:, pending: count - scores.size,
                        done: scores.size, present: count, average_percent: (scores.sum.fdiv(scores.size).round if scores.any?),
                        material_name: material[0], material_slug: material[1], material_category: material[2])
          if week?(row.pending, due_on, today)
            week << row
          elsif due_on && due_on <= today
            history << row
          end
        end
        Result.new(week:, history: history.sort_by { [ -it.due_on.jd, it.classroom_name ] })
      end

      private

      # Sans échéance : tant qu'un élève ne l'a pas fait. À venir (après aujourd'hui) : toujours. Échue, ou échéant aujourd'hui :
      # depuis 14 jours au plus et avec un élève qui ne l'a pas fait. L'échéance est déjà bornée à +AHEAD par la requête.
      def week?(pending, due_on, today)
        return pending.positive? if due_on.nil?
        return true if due_on > today

        pending.positive? && due_on >= today - BEHIND
      end

      # Les assignations actives des classes actives de l'année où il enseigne dans cet établissement, d'un exercice de l'une
      # de ses matières de cet établissement (ADR-0103) : une matière retirée sort de l'accueil, l'assignation reste.
      # Échéance croissante, sans échéance en dernier ; l'historique s'en lit à l'envers.
      def assignments(teacher_id, school_id, today)
        window = Orm::ClassroomAssignment.where(due_on: (today - HISTORY)..(today + AHEAD)).or(Orm::ClassroomAssignment.where(due_on: nil))
        window.joins(:classroom).joins(AssignmentFollowUpQuery::EXERCISE)
              .where(status: "active",
                     classrooms: { school_id:, status: "active", school_year: Entities::Classroom::SchoolYear.current(today),
                                   id: Orm::TeacherClassroom.where(teacher_id:).select(:classroom_id) },
                     courses: { material_id: Orm::TeacherSchoolMaterial.where(teacher_id:, school_id:).select(:material_id) })
              .order(Arel.sql("classroom_assignments.due_on NULLS LAST"), "classrooms.name", :id)
              .pluck(*COLUMNS)
      end

      # Présent : adhésion non quittée, compte non anonymisé (AssignmentFollowUpQuery.present_students, ADR-0072 §4.4).
      def present_counts(classroom_ids)
        Orm::ClassroomStudent.joins(:student).where(classroom_id: classroom_ids, left_at: nil, users: { anonymized_at: nil })
                             .group(:classroom_id).count
      end

      # { assignment_id => [meilleur score de chaque élève qui l'a fait] } : un élève présent de la classe de l'assignation, avec
      # une session terminée qui lui est rattachée, standard ou de remédiation (ADR-0048, ADR-0079 §4.1).
      def best_scores(assignment_ids)
        Orm::ExerciseSession.joins("JOIN classroom_assignments ON classroom_assignments.id = exercise_sessions.classroom_assignment_id")
                            .joins("JOIN classroom_students ON classroom_students.classroom_id = classroom_assignments.classroom_id " \
                                   "AND classroom_students.student_id = exercise_sessions.student_id " \
                                   "AND classroom_students.left_at IS NULL")
                            .joins("JOIN users ON users.id = exercise_sessions.student_id AND users.anonymized_at IS NULL")
                            .where(classroom_assignment_id: assignment_ids, status: "completed")
                            .group(:classroom_assignment_id, :student_id)
                            .pluck(:classroom_assignment_id, Arel.sql("MAX(exercise_sessions.score_percent)"))
                            .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
      end
    end
  end
end

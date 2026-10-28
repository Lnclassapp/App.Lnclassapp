# 🔌 INFRA · Queries::Catalog::PrepareInterrosQuery
# Rôle : les exercices de la leçon pour « Prépare interros », groupés par notion puis « Toute la leçon », avec l'état de l'élève, le statut de l'équipe et les classes de l'enseignant
# ADR  : 0113 · UDR : 0139 §3.4
module Queries
  module Catalog
    class PrepareInterrosQuery
      # groups : [Group] dans l'ordre des notions ; lesson_wide : [ExerciseRow] par position ;
      # targets : Queries::Classroom::CatalogAssignmentTargetsQuery::Targets pour un enseignant, nil pour tout autre rôle.
      Prepare = Data.define(:groups, :lesson_wide, :targets)
      Group = Data.define(:essential_slug, :title, :exercises)
      # student_state : StudentState pour l'élève (nil s'il n'y a rien à dire), nil pour tout autre rôle ; status : celui de l'équipe.
      ExerciseRow = Data.define(:public_id, :title, :exercise_type, :status, :questions_count, :student_state)
      # kind : :to_review (lacune en attente) · :due (assignation active non rendue, due_on) · :score (meilleure note, score_percent).
      StudentState = Data.define(:kind, :due_on, :score_percent)

      EMPTY = Prepare.new(groups: [], lesson_wide: [], targets: nil)
      EXERCISE_COLUMNS = %i[id public_id title exercise_type status essential_id].freeze

      # → Prepare. Un cours inconnu rend des listes vides ; la lecture d'un brouillon est l'affaire de ReadPublishedPolicy, en amont.
      def call(course_slug:, actor:)
        course_id = Orm::Course.where(slug: course_slug).pick(:id)
        return EMPTY if course_id.nil?

        team = actor&.team? || false
        exercises = exercises(course_id, team)
        state_of = actor&.student? ? student_states(exercises, actor.user_id) : {}
        counts = Orm::Question.where(exercise_id: exercises.map(&:first)).group(:exercise_id).count
        rows = exercises.to_h { |values| [ values.first, row(values, counts, state_of) ] }
        Prepare.new(groups: groups(course_id, exercises, rows), lesson_wide: lesson_wide(exercises, rows),
                    targets: targets(course_slug, actor, exercises))
      end

      private

      def exercises(course_id, team)
        scope = Orm::Exercise.where(course_id:).order(:position, :id)
        scope = scope.where(status: "published") unless team
        scope.pluck(*EXERCISE_COLUMNS)
      end

      def row(values, counts, state_of)
        id, public_id, title, exercise_type, status = values
        ExerciseRow.new(public_id:, title:, exercise_type:, status:, questions_count: counts.fetch(id, 0),
                        student_state: state_of[id])
      end

      def groups(course_id, exercises, rows)
        by_essential = exercises.group_by(&:last)
        Orm::Essential.where(course_id:, id: by_essential.keys.compact).order(:position, :id).pluck(:id, :slug, :name)
                      .map { |id, slug, name| Group.new(essential_slug: slug, title: name, exercises: by_essential[id].map { rows[it.first] }) }
      end

      def lesson_wide(exercises, rows) = exercises.select { it.last.nil? }.map { rows[it.first] }

      def targets(course_slug, actor, exercises)
        return unless actor&.teacher?

        Queries::Classroom::CatalogAssignmentTargetsQuery.new.call(
          teacher_id: actor.user_id, school_id: actor.school_id, course_slug:,
          exercise_public_ids: exercises.select { it[4] == "published" }.map { it[1] }
        )
      end

      # { exercise_id => StudentState } : lacune en attente sur la notion, sinon assignation active non rendue, sinon meilleure note.
      def student_states(exercises, student_id)
        ids = exercises.map(&:first)
        gaps = Orm::KnowledgeGap.where(student_id:, status: "pending").pluck(:essential_id).to_set
        due = due_assignments(ids, student_id)
        best = Orm::ExerciseSession.where(student_id:, exercise_id: ids, status: "completed").group(:exercise_id).maximum(:score_percent)
        exercises.each_with_object({}) do |(id, _, _, _, _, essential_id), states|
          state = state(gaps.include?(essential_id), due[id], best[id])
          states[id] = state if state
        end
      end

      def state(gap, due_on, score_percent)
        return StudentState.new(kind: :to_review, due_on: nil, score_percent: nil) if gap
        return StudentState.new(kind: :due, due_on:, score_percent: nil) if due_on
        StudentState.new(kind: :score, due_on: nil, score_percent:) if score_percent
      end

      # { exercise_id => due_on } : l'assignation active à échéance de la classe principale de l'élève, tant qu'il n'en a pas rendu de copie.
      def due_assignments(ids, student_id)
        classrooms = Orm::ClassroomStudent.joins(:classroom)
                                          .where(student_id:, primary: true, left_at: nil, classrooms: { status: "active" })
                                          .select(:classroom_id)
        assignments = Orm::ClassroomAssignment.where(classroom_id: classrooms, status: "active", assignable_type: "Exercise",
                                                     assignable_id: ids).where.not(due_on: nil).pluck(:id, :assignable_id, :due_on)
        handed_in = Orm::ExerciseSession.where(student_id:, status: "completed", classroom_assignment_id: assignments.map(&:first))
                                        .pluck(:classroom_assignment_id).to_set
        assignments.reject { |id, *| handed_in.include?(id) }.to_h { |_, exercise_id, due_on| [ exercise_id, due_on ] }
      end
    end
  end
end

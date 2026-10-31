# 🔌 INFRA · Queries::Classroom::StudentAssignedSheetsQuery
# Rôle : les devoirs reçus de « Ma classe » : les assignations actives de la classe principale de l'élève, une feuille par envoi, la plus récente d'abord ; avant le rendu, ni copie ni correction
# ADR  : 0121 (§4), 0048, 0072 · UDR : 0149 §3 (devoirs reçus par l'élève), CA-13, 14, 16
module Queries
  module Classroom
    class StudentAssignedSheetsQuery
      # Un envoi : kind :interros (1 ou 2 exercices) ou :devoirs (3 ou plus) ; dom_id : le repère de la feuille ; notion / remember : la notion
      # commune à tous les exercices et son « À retenir » (nil sinon) ; notions : leurs noms, sans doublon (la leçon pour un exercice sans
      # notion) ; courses, materials : leurs noms ; assigned_on : le jour de l'envoi ; due_on : l'échéance la plus proche, nil sans échéance ;
      # exercises : [PrepareSheetsQuery::SheetExercise] ; hand_ins : { exercise_public_id => public_id de l'assignation à rendre }.
      Sheet = Data.define(:kind, :dom_id, :assigned_on, :due_on, :notion, :remember, :notions, :courses, :materials, :exercises, :hand_ins)
      Row = Data.define(:id, :public_id, :batch, :assigned_at, :due_on, :exercise_public_id, :course_slug, :course_name, :material_name,
                        :essential_id, :essential_name, :remember)

      DEVOIRS_FROM = 3
      COLUMNS = [ "classroom_assignments.id", "classroom_assignments.public_id", "classroom_assignments.batch_public_id",
                  "classroom_assignments.assigned_at", "classroom_assignments.due_on", "exercises.public_id", "courses.slug", "courses.name",
                  "materials.name", "essentials.id", "essentials.name", Arel.sql("essentials.sheet->>'remember'") ].freeze

      # → [Sheet] ; vide sans classe principale active. Jamais le devoir d'une autre classe : la classe vient de l'appartenance de l'élève.
      def call(actor:)
        return [] unless actor&.student?

        classroom_id = classroom_id(actor.user_id)
        return [] if classroom_id.nil?

        rows = rows(classroom_id, actor.user_id)
        return [] if rows.empty?

        exercises = exercises(rows, actor)
        handed_in = handed_in(rows, actor.user_id)
        sheets(rows, exercises, handed_in)
      end

      private

      def classroom_id(student_id)
        Orm::ClassroomStudent.joins(:classroom).where(student_id:, primary: true, left_at: nil, classrooms: { status: "active" }).pick(:classroom_id)
      end

      # UDR-0013 : rien d'un autre niveau que celui de l'élève ; ADR-0028 : un exercice publié, de sa notion et de son cours publiés.
      def rows(classroom_id, student_id)
        own_level = Queries::Catalog::AudienceFilter.courses(Queries::Catalog::StudentAudienceQuery.new.call(student_id:))
        Orm::ClassroomAssignment
          .joins("INNER JOIN exercises ON exercises.id = classroom_assignments.assignable_id " \
                 "INNER JOIN courses ON courses.id = exercises.course_id " \
                 "INNER JOIN materials ON materials.id = courses.material_id " \
                 "LEFT OUTER JOIN essentials ON essentials.id = exercises.essential_id")
          .where(classroom_id:, status: "active", assignable_type: "Exercise")
          .where(exercises: { status: "published", archived_at: nil }, courses: { status: "published" })
          .where("essentials.id IS NULL OR essentials.status = 'published'")
          .merge(own_level)
          .order("classroom_assignments.id")
          .pluck(*COLUMNS).map { Row.new(*it) }
      end

      # { exercise_public_id => SheetExercise } : la feuille de la leçon lit chaque exercice (questions, indice, figure, dernière copie) ;
      # une lecture par leçon de l'envoi.
      def exercises(rows, actor)
        rows.group_by(&:course_slug).each_with_object({}) do |(slug, course_rows), found|
          prepare = Queries::Catalog::PrepareSheetsQuery.new.call(course_slug: slug, actor:)
          course_rows.each { |row| found[row.exercise_public_id] = prepare.exercise(row.exercise_public_id) }
        end.compact
      end

      # Les assignations dont l'élève a rendu la copie : une copie terminée rattachée (jamais une copie d'entraînement).
      def handed_in(rows, student_id)
        Orm::ExerciseSession.where(student_id:, status: "completed", classroom_assignment_id: rows.map(&:id)).distinct.pluck(:classroom_assignment_id).to_set
      end

      def sheets(rows, exercises, handed_in)
        visible = rows.select { exercises.key?(it.exercise_public_id) }
        visible.group_by { it.batch || it.public_id }
               .values.sort_by { |batch| [ batch.map(&:assigned_at).max, batch.map(&:id).max ] }.reverse
               .map { |batch| sheet(batch, exercises, handed_in) }
      end

      def sheet(batch, exercises, handed_in)
        essentials = batch.map(&:essential_id).uniq
        common = batch.first if essentials.one? && essentials.first
        shown = batch.each_with_index.map do |row, index|
          exercise = exercises.fetch(row.exercise_public_id).with(number: index + 1, due: false)
          handed_in.include?(row.id) ? exercise : unanswered(exercise)
        end
        Sheet.new(kind: batch.size >= DEVOIRS_FROM ? :devoirs : :interros, dom_id: "devoir-#{(batch.first.batch || batch.first.public_id).downcase}",
                  assigned_on: batch.map(&:assigned_at).min.to_date, due_on: batch.filter_map(&:due_on).min,
                  notion: common&.essential_name, remember: common&.remember.presence,
                  notions: batch.map { it.essential_name || it.course_name }.uniq, courses: batch.map(&:course_name).uniq,
                  materials: batch.map(&:material_name).uniq, exercises: shown,
                  hand_ins: batch.to_h { [ it.exercise_public_id, it.public_id ] })
      end

      # CA-16 : avant de rendre, ni note ni correction ni réponse d'une copie d'entraînement antérieure (la feuille rend ce qu'on lui donne).
      def unanswered(exercise)
        questions = exercise.questions.map do |question|
          question.with(response: nil, verdict: nil,
                        choices: question.choices&.map { it.with(picked: false) })
        end
        exercise.with(copy: nil, questions:)
      end
    end
  end
end

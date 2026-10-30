# 🔌 INFRA · Queries::Catalog::LessonAnswerKeyQuery
# Rôle : le corrigé d'une leçon pour l'équipe : tous les exercices non archivés, tous statuts, dans l'ordre de « Prépare interros », avec bonnes réponses et corrections
# ADR  : 0113 (§4.6), 0115 · UDR : 0141-fiche-de-revision-en-quatre-blocs §3.5
module Queries
  module Catalog
    class LessonAnswerKeyQuery
      # exercises : [ExerciseRow] ; questions_count : toutes questions confondues.
      Key = Data.define(:course_slug, :course_name, :status, :exercises) do
        def questions_count = exercises.sum { it.questions.size }
      end
      # essential_name : nil pour un exercice de toute la leçon ; figure : Entities::Catalog::Figure ou nil.
      ExerciseRow = Data.define(:public_id, :title, :essential_name, :statement, :statement_blocks, :figure, :questions)
      QuestionRow = Data.define(:position, :content, :kind_name, :points, :unit, :numeric_tolerance, :explanation, :answers)
      AnswerRow = Data.define(:content, :match_content, :correct)

      EXERCISE_COLUMNS = %i[id public_id title statement statement_blocks figure_key essential_id].freeze

      # → Key | nil (leçon inconnue). L'autorisation est l'affaire de ManageContentPolicy, en amont.
      def call(course_slug:)
        id, name, status, figures = Orm::Course.where(slug: course_slug).pick(:id, :name, :status, :figures)
        return if id.nil?

        Key.new(course_slug:, course_name: name, status:, exercises: exercises(id, Array(figures)))
      end

      private

      def exercises(course_id, figures)
        rows = Orm::Exercise.where(course_id:, archived_at: nil).where.not(status: "archived").order(:position, :id).pluck(*EXERCISE_COLUMNS)
        essentials = Orm::Essential.where(course_id:).order(:position, :id).pluck(:id, :name)
        questions = questions_by_exercise(rows.map(&:first))
        figure_of = figures.map { Entities::Catalog::Figure.from_raw(it) }.index_by(&:key)
        ordered(rows, essentials).map { |row, essential_name| exercise_row(row, essential_name, figure_of, questions) }
      end

      # Les notions dans leur ordre, puis les exercices de toute la leçon, chacun par position.
      def ordered(rows, essentials)
        by_essential = rows.group_by(&:last)
        essentials.flat_map { |id, name| by_essential.fetch(id, []).map { [ it, name ] } } + by_essential.fetch(nil, []).map { [ it, nil ] }
      end

      def exercise_row(row, essential_name, figure_of, questions)
        id, public_id, title, statement, statement_blocks, figure_key = row
        ExerciseRow.new(public_id:, title:, essential_name:, statement:, statement_blocks:, figure: figure_of[figure_key],
                        questions: questions.fetch(id, []))
      end

      def questions_by_exercise(exercise_ids)
        records = Orm::Question.where(exercise_id: exercise_ids).includes(:answers).order(:position)
        records.group_by(&:exercise_id).transform_values { |list| list.map { question_row(it) } }
      end

      def question_row(question)
        answers = question.answers.map { AnswerRow.new(content: it.content, match_content: it.match_content, correct: it.correct) }
        QuestionRow.new(position: question.position, content: question.content, kind_name: Entities::Assessment::Question.kind_name_for(question.question_type),
                        points: question.points, unit: question.unit, numeric_tolerance: question.numeric_tolerance,
                        explanation: question.explanation, answers:)
      end
    end
  end
end

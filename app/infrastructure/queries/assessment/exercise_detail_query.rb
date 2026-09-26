# 🔌 INFRA · Queries::Assessment::ExerciseDetailQuery
# Rôle : un exercice, sa fiche, son cours et ses questions ; sans reveal, answers.correct et l'explication ne sont pas lus
# ADR  : 0026, 0028, 0054 · sécurité n° 29
module Queries
  module Assessment
    class ExerciseDetailQuery
      Row = Data.define(:exercise, :essential, :course, :questions)
      ExerciseRow = Data.define(:public_id, :title, :description, :exercise_type, :status)
      EssentialRow = Data.define(:slug, :name)
      CourseRow = Data.define(:slug, :name, :level_name, :series_name, :material_name, :material_category)
      # Sans reveal, explanation et correct valent nil : leurs colonnes ne sont même pas sélectionnées.
      QuestionRow = Data.define(:id, :position, :content, :question_type, :explanation, :answers)
      AnswerRow = Data.define(:id, :position, :content, :correct)

      EXERCISE_COLUMNS = %w[exercises.id exercises.public_id exercises.title exercises.description exercises.exercise_type
                            exercises.status essentials.slug essentials.name courses.slug courses.name levels.name series.name
                            materials.name materials.category].freeze
      QUESTION_COLUMNS = %i[id position content question_type].freeze
      ANSWER_COLUMNS = %i[question_id id position content].freeze

      # → Row | nil (exercice inconnu). La lecture d'un brouillon est l'affaire de ReadPublishedPolicy, en amont.
      def call(public_id:, reveal:)
        id, *values = Orm::Exercise.joins(essential: { course: %i[level material] })
                                   .joins("LEFT OUTER JOIN series ON series.id = courses.series_id")
                                   .where(public_id:).pick(*EXERCISE_COLUMNS)
        return if id.nil?

        exercise, essential, course = split(values)
        Row.new(exercise:, essential:, course:, questions: questions(id, reveal))
      end

      private

      def split(values)
        public_id, title, description, exercise_type, status, essential_slug, essential_name, *course = values
        slug, name, level_name, series_name, material_name, material_category = course
        [ ExerciseRow.new(public_id:, title:, description:, exercise_type:, status:),
          EssentialRow.new(slug: essential_slug, name: essential_name),
          CourseRow.new(slug:, name:, level_name:, series_name:, material_name:, material_category:) ]
      end

      def questions(exercise_id, reveal)
        rows = Orm::Question.where(exercise_id:).order(:position).pluck(*QUESTION_COLUMNS, *(reveal ? [ :explanation ] : []))
        answers = answers_by_question(rows.map(&:first), reveal)
        rows.map do |id, position, content, question_type, explanation|
          QuestionRow.new(id:, position:, content:, question_type:, explanation:, answers: answers.fetch(id, []))
        end
      end

      # { question_id => [AnswerRow] }, une requête pour toutes les questions.
      def answers_by_question(question_ids, reveal)
        Orm::Answer.where(question_id: question_ids).order(:question_id, :position)
                   .pluck(*ANSWER_COLUMNS, *(reveal ? [ :correct ] : []))
                   .group_by(&:first)
                   .transform_values do |rows|
                     rows.map { |_, id, position, content, correct| AnswerRow.new(id:, position:, content:, correct:) }
                   end
      end
    end
  end
end

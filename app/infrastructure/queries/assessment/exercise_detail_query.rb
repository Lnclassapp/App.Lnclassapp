# 🔌 INFRA · Queries::Assessment::ExerciseDetailQuery
# Rôle : un exercice, sa fiche, son cours et ses questions ; sans reveal, ni correction, ni explication, ni élément d'un nouveau type
# ADR  : 0026, 0028, 0054, 0091 (§4.4) · sécurité n° 29
module Queries
  module Assessment
    class ExerciseDetailQuery
      Row = Data.define(:exercise, :essential, :course, :questions)
      ExerciseRow = Data.define(:public_id, :title, :statement, :exercise_type, :status)
      EssentialRow = Data.define(:slug, :name)
      CourseRow = Data.define(:slug, :name, :level_name, :series_name, :material_name, :material_category)
      # Sans reveal, explanation, correct, numeric_tolerance et match_content valent nil : leurs colonnes ne sont même pas
      # sélectionnées ; les éléments des trous, du nombre, de l'ordre et de relier ne sont pas lus (leur ordre est la solution).
      QuestionRow = Data.define(:id, :position, :content, :question_type, :explanation, :answers, :numeric_tolerance) do
        def initialize(numeric_tolerance: nil, **) = super
        def kind_name = Entities::Assessment::Question.kind_name_for(question_type)
      end
      AnswerRow = Data.define(:id, :position, :content, :correct, :match_content) do
        def initialize(match_content: nil, **) = super
      end

      EXERCISE_COLUMNS = %w[exercises.id exercises.public_id exercises.title exercises.statement exercises.exercise_type
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
        public_id, title, statement, exercise_type, status, essential_slug, essential_name, *course = values
        slug, name, level_name, series_name, material_name, material_category = course
        [ ExerciseRow.new(public_id:, title:, statement:, exercise_type:, status:),
          EssentialRow.new(slug: essential_slug, name: essential_name),
          CourseRow.new(slug:, name:, level_name:, series_name:, material_name:, material_category:) ]
      end

      def questions(exercise_id, reveal)
        rows = Orm::Question.where(exercise_id:).order(:position)
                            .pluck(*QUESTION_COLUMNS, *(reveal ? %i[explanation numeric_tolerance] : []))
        shown = reveal ? rows : rows.select { Entities::Assessment::Question.kind_name_for(it[3]) == "choice" }
        answers = answers_by_question(shown.map(&:first), reveal)
        rows.map do |id, position, content, question_type, explanation, numeric_tolerance|
          QuestionRow.new(id:, position:, content:, question_type:, explanation:, numeric_tolerance:, answers: answers.fetch(id, []))
        end
      end

      # { question_id => [AnswerRow] }, une requête pour toutes les questions.
      def answers_by_question(question_ids, reveal)
        Orm::Answer.where(question_id: question_ids).order(:question_id, :position)
                   .pluck(*ANSWER_COLUMNS, *(reveal ? %i[correct match_content] : []))
                   .group_by(&:first)
                   .transform_values do |rows|
                     rows.map do |_, id, position, content, correct, match_content|
                       AnswerRow.new(id:, position:, content:, correct:, match_content:)
                     end
                   end
      end
    end
  end
end

# 🔌 INFRA · Queries::Assessment::ExerciseDetailQuery
# Rôle : le sujet d'un exercice de la leçon (notion facultative), son cours et ses questions, propositions mélangées de la graine de l'exercice ;
#        sans reveal, ni correction, ni explication, ni solution d'un nouveau type
# ADR  : 0026, 0028, 0054, 0091 (§4.4), 0112, 0113 · UDR : 0138 §3.1 · sécurité n° 29
module Queries
  module Assessment
    class ExerciseDetailQuery
      # essential : nil pour un exercice de toute la leçon.
      Row = Data.define(:exercise, :essential, :course, :questions)
      ExerciseRow = Data.define(:id, :public_id, :title, :statement, :exercise_type, :status)
      EssentialRow = Data.define(:slug, :name)
      CourseRow = Data.define(:slug, :name, :level_name, :series_name, :material_name, :material_category)
      # Sans reveal, explanation, correct, numeric_tolerance et match_content valent nil : leurs colonnes ne sont même pas
      # sélectionnées. La feuille de l'élève montre pourtant les étapes (ordering) et les deux colonnes (matching) : items est
      # la colonne mélangée (étapes, colonne de droite) sans ordre juste, prompts la colonne de gauche ; image : Image ou nil.
      QuestionRow = Data.define(:id, :position, :content, :question_type, :explanation, :answers, :numeric_tolerance,
                                :items, :prompts, :image) do
        def initialize(numeric_tolerance: nil, items: [], prompts: [], image: nil, **) = super
        def kind_name = Entities::Assessment::Question.kind_name_for(question_type)
      end
      AnswerRow = Data.define(:id, :position, :content, :correct, :match_content) do
        def initialize(match_content: nil, **) = super
      end

      Item = Data.define(:index, :content)
      Image = SessionPlayQuery::Image

      EXERCISE_COLUMNS = %w[exercises.id exercises.public_id exercises.title exercises.statement exercises.exercise_type
                            exercises.status essentials.slug essentials.name courses.slug courses.name levels.name series.name
                            materials.name materials.category].freeze
      QUESTION_COLUMNS = %i[id position content question_type].freeze
      ANSWER_COLUMNS = %i[question_id id position content].freeze

      # → Row | nil (exercice inconnu). La lecture d'un brouillon est l'affaire de ReadPublishedPolicy, en amont.
      def call(public_id:, reveal:)
        id, *values = Orm::Exercise.joins(course: %i[level material])
                                   .joins("LEFT OUTER JOIN series ON series.id = courses.series_id")
                                   .joins("LEFT OUTER JOIN essentials ON essentials.id = exercises.essential_id")
                                   .where(public_id:).pick(*EXERCISE_COLUMNS)
        return if id.nil?

        exercise, essential, course = split(id, values)
        Row.new(exercise:, essential:, course:, questions: questions(id, reveal))
      end

      private

      def split(id, values)
        public_id, title, statement, exercise_type, status, essential_slug, essential_name, *course = values
        slug, name, level_name, series_name, material_name, material_category = course
        [ ExerciseRow.new(id:, public_id:, title:, statement:, exercise_type:, status:),
          (EssentialRow.new(slug: essential_slug, name: essential_name) if essential_slug),
          CourseRow.new(slug:, name:, level_name:, series_name:, material_name:, material_category:) ]
      end

      def questions(exercise_id, reveal)
        rows = Orm::Question.where(exercise_id:).order(:position)
                            .pluck(*QUESTION_COLUMNS, *(reveal ? %i[explanation numeric_tolerance] : []))
        shown = reveal ? rows : rows.select { Entities::Assessment::Question.kind_name_for(it[3]) == "choice" }
        answers = answers_by_question(shown.map(&:first), reveal)
        elements = elements_by_question(rows)
        images = images_by_question(rows.map(&:first))
        rows.map do |id, position, content, question_type, explanation, numeric_tolerance|
          kind = Entities::Assessment::Question.kind_name_for(question_type)
          QuestionRow.new(id:, position:, content:, question_type:, explanation:, numeric_tolerance:, image: images[id],
                          answers: shuffle_choices(exercise_id, id, kind, answers.fetch(id, [])),
                          **sheet(exercise_id, id, kind, elements.fetch(id, [])))
        end
      end

      # Mélange de la feuille : la graine est l'exercice, jamais l'ordre de saisie, qui trahirait l'ordre juste (UDR-0138 §3.1).
      def shuffle_choices(exercise_id, question_id, kind, answers)
        return answers unless kind == "choice"

        by_id = answers.index_by(&:id)
        Entities::Assessment::AnswerShuffle.for(session_id: exercise_id, question_id:, ids: by_id.keys).map { by_id.fetch(it) }
      end

      # { question_id => [[id, content, match_content]] } des questions à ordonner ou à relier, dans l'ordre des positions : une requête.
      def elements_by_question(rows)
        ids = rows.select { %w[ordering matching].include?(Entities::Assessment::Question.kind_name_for(it[3])) }.map(&:first)
        return {} if ids.empty?

        Orm::Answer.where(question_id: ids).order(:question_id, :position, :id).pluck(:question_id, :id, :content, :match_content)
                   .group_by(&:first).transform_values { |list| list.map { it.drop(1) } }
      end

      def sheet(exercise_id, question_id, kind, elements)
        case kind
        when "ordering" then { items: items(exercise_id, question_id, elements.to_h { |id, content, _| [ id, content ] }) }
        when "matching"
          { prompts: elements.map { it[1] }, items: items(exercise_id, question_id, elements.to_h { |id, _, right| [ id, right ] }) }
        else {}
        end
      end

      # contents : { id => texte } dans l'ordre des positions, qui est la solution que le mélange évite.
      def items(exercise_id, question_id, contents)
        Entities::Assessment::AnswerShuffle.for(session_id: exercise_id, question_id:, ids: contents.keys, avoid: contents.keys)
                                           .each_with_index.map { |id, index| Item.new(index:, content: contents[id]) }
      end

      def images_by_question(question_ids)
        Orm::QuestionImage.where(question_id: question_ids).pluck(:question_id, :public_id, :alt, :width, :height)
                          .to_h { |question_id, *image| [ question_id, Image.new(*image) ] }
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

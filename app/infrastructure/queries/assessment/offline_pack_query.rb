# 🔌 INFRA · Queries::Assessment::OfflinePackQuery
# Rôle : le paquet de corrigé d'un exercice (questions avec bonnes réponses, explications, ordre d'affichage, empreinte) et la feuille de la copie hors ligne (sans aucune correction, sans session)
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.4, §4.7 : seul ce JSON porte le corrigé, à l'élève autorisé) · menace C1, C3 · UDR : hors-connexion §3.4
module Queries
  module Assessment
    class OfflinePackQuery
      Pack = Data.define(:exercise_id, :exercise_public_id, :title, :digest, :questions)

      QUESTION_COLUMNS = %i[id position content explanation question_type points unit numeric_tolerance starter].freeze
      ANSWER_COLUMNS = %i[question_id id position content match_content correct blank].freeze
      SHUFFLED_KINDS = %w[choice select ordering matching].freeze
      ORDERED_KINDS = %w[ordering matching].freeze

      # 16 hexadécimaux du SHA-256 du JSON canonique (clés triées à tous les niveaux) : l'empreinte de la version des questions.
      def self.digest(questions) = Digest::SHA256.hexdigest(canonical(questions).to_json)[0, 16]

      def self.canonical(value)
        case value
        when Hash then value.to_h { |key, item| [ key.to_s, canonical(item) ] }.sort.to_h
        when Array then value.map { canonical(it) }
        else value
        end
      end

      # → Pack | nil. Le mélange d'affichage a pour graine l'identifiant de l'exercice (la copie hors ligne n'a pas de session) :
      # display, par question à éléments mélangés, est la liste des rangs (indices dans answers) dans l'ordre où la feuille les montre ; aucun identifiant de proposition n'en sort.
      def call(public_id:)
        exercise = Orm::Exercise.find_by(public_id:)
        return if exercise.nil?

        questions = payload(exercise)
        Pack.new(exercise_id: exercise.id, exercise_public_id: exercise.public_id, title: exercise.title, digest: self.class.digest(questions), questions:)
      end

      # La copie sans correction, au même format que SessionPlayQuery::Copy (les partials de la copie en ligne la lisent), session_public_id nil.
      # Aucun identifiant de proposition n'y est mis : la feuille ne dit que l'indice d'affichage.
      # → SessionPlayQuery::Copy | nil
      def sheet(public_id:)
        exercise = Orm::Exercise.includes(:course).find_by(public_id:)
        return if exercise.nil?

        rows = questions_of(exercise)
        answers = answers_of(rows)
        images = Orm::QuestionImage.where(question_id: rows.map(&:id)).pluck(:question_id, :public_id, :alt, :width, :height)
                                   .to_h { |question_id, *image| [ question_id, SessionPlayQuery::Image.new(*image) ] }
        questions = rows.each_with_index.map { |question, index| sheet_question(exercise, question, index + 1, answers.fetch(question.id, []), images[question.id]) }
        SessionPlayQuery::Copy.new(session_public_id: nil, student_id: nil, status: nil, exercise_public_id: exercise.public_id, exercise_title: exercise.title,
                                   statement: exercise.statement, question_count: questions.size, questions:, statement_blocks: exercise.statement_blocks,
                                   figure: SessionPlayQuery.figure_for(exercise.course.figures, exercise.figure_key))
      end

      private

      def questions_of(exercise) = Orm::Question.where(exercise_id: exercise.id).order(:position, :id).select(*QUESTION_COLUMNS).to_a

      def answers_of(rows)
        Orm::Answer.where(question_id: rows.map(&:id)).order(:question_id, :position, :id).select(*ANSWER_COLUMNS).group_by(&:question_id)
      end

      def payload(exercise)
        rows = questions_of(exercise)
        answers = answers_of(rows)
        rows.map { |question| question_payload(exercise, question, answers.fetch(question.id, [])) }
      end

      def question_payload(exercise, question, answers)
        kind = kind_name(question.question_type)
        base = { id: question.id, kind:, question_type: question.question_type, content: question.content, explanation: question.explanation,
                 points: question.points.to_s("F"), unit: question.unit, numeric_tolerance: question.numeric_tolerance&.to_s("F"),
                 answers: answers.map { { position: it.position, content: it.content, match_content: it.match_content, correct: it.correct, blank: it.blank } } }
        base[:display] = display_ranks(exercise, question.id, answers, kind) if SHUFFLED_KINDS.include?(kind)
        base
      end

      # Le mélange se tire sur les identifiants (même graine que la feuille), mais le paquet ne dit que des rangs : le rang d'une proposition
      # est sa place dans answers (ordre position, id). Le serveur retrouve l'identifiant avec le même ordre.
      def display_ranks(exercise, question_id, answers, kind)
        ids = answers.map(&:id)
        shuffled(exercise, question_id, ids, kind).map { ids.index(it) }
      end

      def shuffled(exercise, question_id, ids, kind)
        Entities::Assessment::AnswerShuffle.for(session_id: exercise.id, question_id:, ids:, avoid: (ids if ORDERED_KINDS.include?(kind)))
      end

      def sheet_question(exercise, question, number, answers, image)
        kind = kind_name(question.question_type)
        SessionPlayQuery::Question.new(id: question.id, number:, content: question.content, question_type: question.question_type, answers: [], image:,
                                       points: question.points, unit: question.unit, starter: question.starter, blanks: (answers.map(&:blank).max || 0) + 1,
                                       **sheet_items(exercise, question, kind, answers))
      end

      def sheet_items(exercise, question, kind, answers)
        order = shuffled(exercise, question.id, answers.map(&:id), kind) if SHUFFLED_KINDS.include?(kind)
        by_id = answers.index_by(&:id)
        case kind
        when "choice", "select"
          { answers: order.each_with_index.map { |id, index| SessionPlayQuery::Answer.new(id: nil, content: by_id[id].content, index:, blank: by_id[id].blank) } }
        when "ordering" then { items: order.each_with_index.map { |id, index| SessionPlayQuery::Item.new(index:, content: by_id[id].content) } }
        when "matching"
          { prompts: answers.map(&:content), items: order.each_with_index.map { |id, index| SessionPlayQuery::Item.new(index:, content: by_id[id].match_content) } }
        else {}
        end
      end

      def kind_name(question_type) = Entities::Assessment::Question.kind_name_for(question_type)
    end
  end
end

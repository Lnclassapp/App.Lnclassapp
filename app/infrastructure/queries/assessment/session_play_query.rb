# 🔌 INFRA · Queries::Assessment::SessionPlayQuery
# Rôle : écran d'une session : progression, prochaine question sans aucune correction ni id révélateur, son image, verdict de la question tentée
# ADR  : 0028, 0054, 0091 (§4.4 : rien de la solution dans la page), 0105 · UDR : 0007, 0022, 0087, 0129
module Queries
  module Assessment
    class SessionPlayQuery
      Row = Data.define(:session_public_id, :student_id, :status, :exercise_public_id, :exercise_title, :answered_count,
                        :question_count, :progress_percent, :next_question, :last_feedback) do
        def completed? = status == "completed"
        # Rang de la question où l'élève reprendra (UDR-0087 §3.3).
        def resume_number = answered_count + 1
      end
      # number : rang de la question dans l'exercice ; image : son image au-dessus de l'énoncé, ou nil (ADR-0105). Par type (ADR-0091 §4.4) :
      # - answers : les propositions mélangées d'une question à cocher, avec leur id ; vide pour tout autre type ;
      # - items : les étapes (ordering) ou la colonne de droite (matching), mélangées, sans id : seul leur indice d'affichage ;
      # - prompts : la colonne de gauche d'un matching, dans l'ordre des positions, sans id.
      # Trous et nombre : rien de tout cela, aucune ligne answers n'est lue.
      Question = Data.define(:id, :number, :content, :question_type, :answers, :items, :prompts, :image) do
        def initialize(items: [], prompts: [], image: nil, **) = super
        def kind_name = Entities::Assessment::Question.kind_name_for(question_type)
        def expected_count = Entities::Assessment::Question::EXPECTED.fetch(question_type.to_sym)
        def multiple? = expected_count > 1
      end
      # Jamais de colonne correct : une proposition montrée à l'élève ne dit pas si elle est juste. index : rang d'affichage.
      Answer = Data.define(:id, :content, :index)
      Item = Data.define(:index, :content)
      Pair = Data.define(:left, :right)
      # Assez pour <img> : adresse, texte de remplacement, dimensions contre le saut de mise en page (UDR-0129 §3.4).
      Image = Data.define(:public_id, :alt, :width, :height)
      # correct : verdict de la tentative ; selected_answers : les seules propositions que l'élève a cochées (choix), ou ses
      # étapes dans son ordre (ordering) ; response_text : son texte (trous, nombre) ; pairs : ses paires (matching).
      Feedback = Data.define(:question_id, :number, :content, :explanation, :correct, :question_type, :selected_answers,
                             :response_text, :pairs) do
        def kind_name = Entities::Assessment::Question.kind_name_for(question_type)
      end

      SESSION_COLUMNS = %w[exercise_sessions.id exercise_sessions.public_id exercise_sessions.student_id exercise_sessions.status
                           exercise_sessions.answered_count exercise_sessions.question_count exercise_sessions.progress_percent
                           exercises.id exercises.public_id exercises.title].freeze

      # feedback_question_id : question qui vient d'être soumise ; son verdict n'est lu que si elle est tentée.
      # → Row | nil
      def call(public_id:, feedback_question_id: nil)
        id, public_id, student_id, status, answered_count, question_count, progress_percent, exercise_id, exercise_public_id,
          exercise_title = Orm::ExerciseSession.joins(:exercise).where(public_id:).pick(*SESSION_COLUMNS)
        return if id.nil?

        questions = Orm::Question.where(exercise_id:).order(:position, :id).pluck(:id, :content, :explanation, :question_type)
        attempts = Orm::QuestionAttempt.where(exercise_session_id: id).pluck(:question_id, :correct, :selected_answer_ids, :response_text)
                                       .to_h { |question_id, *attempt| [ question_id, attempt ] }
        Row.new(session_public_id: public_id, student_id:, status:, exercise_public_id:, exercise_title:, answered_count:,
                question_count:, progress_percent:, next_question: next_question(id, questions, attempts),
                last_feedback: feedback(id, questions, attempts, feedback_question_id))
      end

      private

      def kind_name(question_type) = Entities::Assessment::Question.kind_name_for(question_type)

      # Première question, par position, sans tentative dans cette session.
      def next_question(session_id, questions, attempts)
        index = questions.index { |question_id, *| !attempts.key?(question_id) }
        return if index.nil?

        question_id, content, _explanation, question_type = questions[index]
        Question.new(id: question_id, number: index + 1, content:, question_type:, answers: [], image: image(question_id),
                     **displayed(session_id, question_id, question_type))
      end

      def image(question_id)
        row = Orm::QuestionImage.where(question_id:).pick(:public_id, :alt, :width, :height)
        row && Image.new(*row)
      end

      # Ce que la page montre avant la réponse, par type ; les identifiants ne servent qu'au mélange, ici, côté serveur.
      def displayed(session_id, question_id, question_type)
        case kind_name(question_type)
        when "choice"
          rows = Orm::Answer.where(question_id:).pluck(:id, :content).to_h
          { answers: shuffled(session_id, question_id, rows.keys).each_with_index.map { |id, index| Answer.new(id:, content: rows[id], index:) } }
        when "ordering"
          { items: items(session_id, question_id, Orm::Answer.where(question_id:).order(:position, :id).pluck(:id, :content).to_h) }
        when "matching"
          rows = Orm::Answer.where(question_id:).order(:position, :id).pluck(:id, :content, :match_content)
          { prompts: rows.map { it[1] }, items: items(session_id, question_id, rows.to_h { |id, _, right| [ id, right ] }) }
        else {}
        end
      end

      # contents : { id => texte }, dans l'ordre des positions, qui est la solution que le mélange évite (ADR-0091 §4.4).
      def items(session_id, question_id, contents)
        Entities::Assessment::AnswerShuffle.for(session_id:, question_id:, ids: contents.keys, avoid: contents.keys)
                                           .each_with_index.map { |id, index| Item.new(index:, content: contents[id]) }
      end

      # Mélangées, mais dans le même ordre à chaque affichage de la même session (AS-09, ADR-0091 §4.4).
      def shuffled(session_id, question_id, ids) = Entities::Assessment::AnswerShuffle.for(session_id:, question_id:, ids:)

      def feedback(session_id, questions, attempts, question_id)
        index = questions.index { |id, *| id == question_id && attempts.key?(id) }
        return if index.nil?

        _id, content, explanation, question_type = questions[index]
        correct, selected_ids, response_text = attempts.fetch(question_id)
        Feedback.new(question_id:, number: index + 1, content:, explanation:, correct:, question_type:, response_text:,
                     **choices(session_id, question_id, question_type, selected_ids))
      end

      # Filtrées par la base pour un choix : une proposition juste que l'élève n'a pas cochée n'est jamais lue (UDR-0022).
      # Pour l'ordre et relier, les éléments sont lus, mais seule la réponse de l'élève est rendue (ADR-0091 §4.4).
      def choices(session_id, question_id, question_type, ids)
        case kind_name(question_type)
        when "choice"
          order = shuffled(session_id, question_id, Orm::Answer.where(question_id:).pluck(:id))
          selected = Orm::Answer.where(question_id:, id: ids).order(:position, :id).pluck(:id, :content)
          { selected_answers: selected.map { |id, content| Answer.new(id:, content:, index: order.index(id)) }, pairs: [] }
        when "ordering"
          contents = Orm::Answer.where(question_id:, id: ids).pluck(:id, :content).to_h
          { selected_answers: ids.each_with_index.map { |id, index| Answer.new(id: nil, content: contents[id], index:) }, pairs: [] }
        when "matching" then { selected_answers: [], pairs: pairs(question_id, ids) }
        else { selected_answers: [], pairs: [] }
        end
      end

      # Les paires de l'élève : chaque élément de gauche, dans l'ordre des positions, avec le côté droit qu'il a choisi.
      def pairs(question_id, ids)
        rows = Orm::Answer.where(question_id:).order(:position, :id).pluck(:id, :content, :match_content)
        rights = rows.to_h { |id, _, right| [ id, right ] }
        rows.zip(ids).map { |(_, left, _), id| Pair.new(left:, right: rights[id]) }
      end
    end
  end
end

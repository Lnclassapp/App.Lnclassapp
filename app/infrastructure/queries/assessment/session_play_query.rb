# 🔌 INFRA · Queries::Assessment::SessionPlayQuery
# Rôle : écran d'une session : progression, prochaine question sans aucune correction, verdict de la question tentée
# ADR  : 0028, 0054 · UDR : 0007, 0022
module Queries
  module Assessment
    class SessionPlayQuery
      Row = Data.define(:session_public_id, :student_id, :status, :exercise_public_id, :exercise_title, :answered_count,
                        :question_count, :progress_percent, :next_question, :last_feedback) do
        def completed? = status == "completed"
      end
      # number : rang de la question dans l'exercice ; expected_count : nombre de propositions à cocher (ADR-0054).
      Question = Data.define(:id, :number, :content, :question_type, :answers) do
        def expected_count = Entities::Assessment::Question::EXPECTED.fetch(question_type.to_sym)
        def multiple? = expected_count > 1
      end
      # Jamais de colonne correct : une proposition montrée à l'élève ne dit pas si elle est juste.
      Answer = Data.define(:id, :content)
      # correct : verdict de la tentative ; selected_answers : les seules propositions que l'élève a cochées.
      Feedback = Data.define(:question_id, :number, :content, :explanation, :correct, :selected_answers)

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
        attempts = Orm::QuestionAttempt.where(exercise_session_id: id).pluck(:question_id, :correct, :selected_answer_ids)
                                       .to_h { |question_id, correct, selected| [ question_id, [ correct, selected ] ] }
        Row.new(session_public_id: public_id, student_id:, status:, exercise_public_id:, exercise_title:, answered_count:,
                question_count:, progress_percent:, next_question: next_question(id, questions, attempts),
                last_feedback: feedback(questions, attempts, feedback_question_id))
      end

      private

      # Première question, par position, sans tentative dans cette session.
      def next_question(session_id, questions, attempts)
        index = questions.index { |question_id, *| !attempts.key?(question_id) }
        return if index.nil?

        question_id, content, _explanation, question_type = questions[index]
        Question.new(id: question_id, number: index + 1, content:, question_type:, answers: answers(session_id, question_id))
      end

      def feedback(questions, attempts, question_id)
        index = questions.index { |id, *| id == question_id && attempts.key?(id) }
        return if index.nil?

        _id, content, explanation, = questions[index]
        correct, selected_answer_ids = attempts.fetch(question_id)
        Feedback.new(question_id:, number: index + 1, content:, explanation:, correct:,
                     selected_answers: selected_answers(question_id, selected_answer_ids))
      end

      # Filtrées par la base : une proposition juste que l'élève n'a pas cochée n'est jamais lue (UDR-0022).
      def selected_answers(question_id, ids)
        Orm::Answer.where(question_id:, id: ids).order(:position, :id).pluck(:id, :content)
                   .map { |id, content| Answer.new(id:, content:) }
      end

      # Mélangées, mais dans le même ordre à chaque affichage de la même session (AS-09).
      def answers(session_id, question_id)
        Orm::Answer.where(question_id:).order(:id).pluck(:id, :content)
                   .shuffle(random: Random.new(session_id ^ question_id))
                   .map { |id, content| Answer.new(id:, content:) }
      end
    end
  end
end

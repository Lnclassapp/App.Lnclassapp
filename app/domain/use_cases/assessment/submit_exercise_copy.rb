# 🧠 DOMAINE · UseCases::Assessment::SubmitExerciseCopy
# Rôle : l'élève rend la copie entière d'un exercice : toutes les réponses lues, corrigées, notées et la session close, en un envoi
# ADR  : 0026, 0054, 0091 (§4.4 : indices d'affichage relus par AnswerShuffle), 0112 · UDR : 0138
module UseCases
  module Assessment
    class SubmitExerciseCopy
      # already_closed : la copie était déjà rendue, rien n'a été écrit ; closed : Row de CloseExerciseSession, sinon nil.
      Submitted = Data.define(:session_public_id, :already_closed, :closed)

      def initialize(sessions:, exercises:, policy:, close:, transaction:, clock:)
        @sessions = sessions
        @exercises = exercises
        @policy = policy
        @close = close
        @transaction = transaction
        @clock = clock
      end

      # dto : Dtos::Assessment::CopyInput.
      # → Result(Submitted) | :not_found | :forbidden (autre élève, autre rôle)
      #   | :invalid (errors : { numéro de question => { champ => [code] } }, ou { base: [:invalid_copy] } pour une copie qui ne
      #     se lit pas : question étrangère, trop de réponses ; rien n'est écrit)
      #   | :conflict (base: session_closed, session abandonnée ; base: exercise_archived)
      def call(actor:, dto:)
        @transaction.call do
          # Verrou : deux envois de la même copie passent l'un après l'autre, le second ne trouve plus rien à écrire.
          session = @sessions.find_by_public_id(public_id: dto.session_public_id, lock: true)
          next Shared::Result.failure(:not_found) if session.nil?
          next Shared::Result.failure(:forbidden) unless actor&.student? && session.student_id == actor.user_id
          next already_closed(session) if session.completed?

          allowed = @policy.call(actor:, session:)
          next Shared::Result.failure(:conflict, errors: allowed.errors) if closed?(allowed)
          next allowed if allowed.failure?

          submit(actor, session, dto)
        end
      end

      private

      def already_closed(session) = Shared::Result.success(Submitted.new(session_public_id: session.public_id, already_closed: true, closed: nil))

      def closed?(allowed) = allowed.errors.fetch(:base, []).include?(:session_closed)

      def submit(actor, session, dto)
        exercise = @exercises.find(id: session.exercise_id)
        return Shared::Result.failure(:not_found) if exercise.nil?
        return Shared::Result.failure(:conflict, errors: { base: [ :exercise_archived ] }) if exercise.status == "archived"

        attempts = grade(session, exercise, dto)
        return attempts if attempts.failure?

        recorded = @sessions.record_copy(session_id: session.id, attempts: attempts.value, at: @clock.now)
        return Shared::Result.failure(:conflict, errors: { base: [ :already_answered ] }) if recorded == :duplicate

        closed = @close.call(actor:, session:, essential_id: exercise.essential_id)
        Shared::Result.success(Submitted.new(session_public_id: session.public_id, already_closed: false, closed: closed.value))
      end

      # Une tentative par question de l'exercice, dans l'ordre. Une réponse mal formée refuse la copie entière.
      def grade(session, exercise, dto)
        questions = exercise.questions
        return invalid_copy unless dto.valid? && dto.answers.size <= questions.size && (dto.answers.keys - questions.map(&:id)).empty?

        errors = {}
        attempts = questions.each_with_index.map do |question, index|
          input = dto.answers[question.id]
          next unanswered(question) if input.nil?

          attempt, problems = attempt_for(session, question, input)
          errors[index + 1] = problems if problems
          attempt
        end
        errors.empty? ? Shared::Result.success(attempts) : Shared::Result.failure(:invalid, errors:)
      end

      def invalid_copy = Shared::Result.failure(:invalid, errors: { base: [ :invalid_copy ] })

      def unanswered(question)
        { question_id: question.id, selected_answer_ids: [], response_text: nil, correct: false, unanswered: true }
      end

      # → [tentative, nil] | [nil, erreurs]
      def attempt_for(session, question, input)
        return [ nil, input.errors.details.transform_values { |details| details.pluck(:error) } ] unless input.valid?

        response = response_for(question, session, input)
        return [ nil, question.kind::INVALID ] unless question.well_formed?(response)

        [ { question_id: question.id, selected_answer_ids: response.is_a?(String) ? [] : response,
            response_text: (response if response.is_a?(String)), correct: question.correct?(response), unanswered: false }, nil ]
      end

      # Ce que la question corrige : le texte saisi, les identifiants cochés, ou ceux que désignent les indices d'affichage
      # (ADR-0091 §4.4), reconstitués par le mélange de la session ; dans l'ordre de l'élève.
      def response_for(question, session, input)
        case question.kind::INPUT
        when :response_text then input.response_text.to_s
        when :display_order
          shuffled = Entities::Assessment::AnswerShuffle.for(session_id: session.id, question_id: question.id, ids: question.answer_ids,
                                                             avoid: question.ids_by_position)
          Entities::Assessment::AnswerShuffle.pick(shuffled, input.display_order)
        else input.answer_ids
        end
      end
    end
  end
end

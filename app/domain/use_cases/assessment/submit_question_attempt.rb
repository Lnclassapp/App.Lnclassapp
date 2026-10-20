# 🧠 DOMAINE · UseCases::Assessment::SubmitQuestionAttempt
# Rôle : l'élève répond une fois à une question de sa session ouverte ; la dernière réponse clôt la session
# ADR  : 0026, 0028, 0054, 0091 (§4.4 : indices d'affichage relus par AnswerShuffle)
module UseCases
  module Assessment
    class SubmitQuestionAttempt
      # closed : Row de CloseExerciseSession quand cette réponse était la dernière, sinon nil.
      Submitted = Data.define(:session_public_id, :question_id, :correct, :closed)

      def initialize(sessions:, exercises:, policy:, close:, transaction:, clock:)
        @sessions = sessions
        @exercises = exercises
        @policy = policy
        @close = close
        @transaction = transaction
        @clock = clock
      end

      # dto : Dtos::Assessment::AttemptInput.
      # → Result(Submitted) | :not_found | :forbidden | :invalid (answer_ids, response_text ou display_order)
      #   | :conflict (base: already_answered, ou session_closed : session terminée ou abandonnée, ADR-0054)
      def call(actor:, dto:)
        @transaction.call do
          # Verrou : deux soumissions de la même session passent l'une après l'autre (sécurité n° 30).
          session = @sessions.find_by_public_id(public_id: dto.session_public_id, lock: true)
          next Shared::Result.failure(:not_found) if session.nil?

          allowed = @policy.call(actor:, session:)
          next Shared::Result.failure(:conflict, errors: allowed.errors) if closed?(allowed)
          next allowed if allowed.failure?
          next Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

          answer(actor, session, dto)
        end
      end

      private

      def closed?(allowed) = allowed.errors.fetch(:base, []).include?(:session_closed)

      def answer(actor, session, dto)
        exercise = @exercises.find(id: session.exercise_id)
        question = exercise.questions.find { it.id == dto.question_id }
        return Shared::Result.failure(:invalid, errors: { answer_ids: [ :wrong_selection ] }) if question.nil?

        response = response_for(question, session, dto)
        return Shared::Result.failure(:invalid, errors: question.kind::INVALID) unless question.well_formed?(response)

        correct = question.correct?(response)
        recorded = @sessions.record_attempt(session_id: session.id, question_id: question.id, correct:, at: @clock.now,
                                            selected_answer_ids: response.is_a?(String) ? [] : response,
                                            response_text: (response if response.is_a?(String)))
        return Shared::Result.failure(:conflict, errors: { base: [ :already_answered ] }) if recorded == :duplicate

        Shared::Result.success(Submitted.new(session_public_id: session.public_id, question_id: question.id, correct:,
                                             closed: close(actor, session, exercise)))
      end

      # Ce que la question corrige : le texte saisi, les identifiants cochés, ou ceux que désignent les indices d'affichage
      # (ADR-0091 §4.4), reconstitués par le mélange de la session ; dans l'ordre de l'élève.
      def response_for(question, session, dto)
        case question.kind::INPUT
        when :response_text then dto.response_text.to_s
        when :display_order
          shuffled = Entities::Assessment::AnswerShuffle.for(session_id: session.id, question_id: question.id, ids: question.answer_ids,
                                                             avoid: question.ids_by_position)
          Entities::Assessment::AnswerShuffle.pick(shuffled, dto.display_order)
        else dto.answer_ids
        end
      end

      # À la dernière réponse, la clôture se fait dans la même transaction (ADR-0054). Sa policy est celle qui vient
      # d'autoriser la réponse, sur la même session verrouillée : elle ne peut pas refuser ici.
      def close(actor, session, exercise)
        return unless session.with(answered_count: session.answered_count + 1).complete?

        @close.call(actor:, session:, essential_id: exercise.essential_id).value
      end
    end
  end
end

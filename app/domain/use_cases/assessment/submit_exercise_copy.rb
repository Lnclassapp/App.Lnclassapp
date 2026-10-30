# 🧠 DOMAINE · UseCases::Assessment::SubmitExerciseCopy
# Rôle : l'élève rend la copie entière d'un exercice : toutes les réponses lues, corrigées, notées et la session close, en un envoi
# ADR  : 0026, 0054, 0091 (§4.4 : indices d'affichage relus par AnswerShuffle), 0112, 0115 (réponse rédigée, cahier), XXXX-questions-a-plusieurs-cases-et-indice (§4 : une réponse et un verdict par case) · UDR : 0138
module UseCases
  module Assessment
    class SubmitExerciseCopy
      # already_closed : la copie était déjà rendue, rien n'a été écrit ; closed : Row de CloseExerciseSession, sinon nil.
      Submitted = Data.define(:session_public_id, :already_closed, :closed)

      # Lève dans la transaction pour l'annuler quand la clôture échoue : les tentatives écrites ne restent pas sans session close.
      Rollback = Class.new(StandardError) do
        attr_reader :failure

        def initialize(failure)
          @failure = failure
          super("copie non rendue")
        end
      end

      # Les types qui jugent case par case (ADR cases §4) ; les autres n'ont jamais qu'une case.
      BLANK_KINDS = [ Entities::Assessment::QuestionKinds::Numeric, Entities::Assessment::QuestionKinds::FillBlank,
                      Entities::Assessment::QuestionKinds::Select ].freeze
      BLANK_SEPARATOR = " ; ".freeze
      INVALID_PICK = :invalid_pick

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
        rolled_back { @transaction.call { locked(actor, dto) } }
      end

      private

      def rolled_back
        yield
      rescue Rollback => e
        e.failure
      end

      def locked(actor, dto)
        # Verrou : deux envois de la même copie passent l'un après l'autre, le second ne trouve plus rien à écrire.
        session = @sessions.find_by_public_id(public_id: dto.session_public_id, lock: true)
        return Shared::Result.failure(:not_found) if session.nil?
        return Shared::Result.failure(:forbidden) unless actor&.student? && session.student_id == actor.user_id
        return already_closed(session) if session.completed?

        allowed = @policy.call(actor:, session:)
        return Shared::Result.failure(:conflict, errors: allowed.errors) if closed?(allowed)
        return allowed if allowed.failure?

        submit(actor, session, dto)
      end

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
        raise Rollback.new(closed) if closed.failure?

        Shared::Result.success(Submitted.new(session_public_id: session.public_id, already_closed: false, closed: closed.value))
      end

      # Une tentative par question de l'exercice, dans l'ordre. Une réponse mal formée refuse la copie entière.
      def grade(session, exercise, dto)
        questions = exercise.questions
        return invalid_copy unless dto.valid? && dto.answers.size <= questions.size && (dto.answers.keys - questions.map(&:id)).empty?

        errors = {}
        attempts = questions.each_with_index.map do |question, index|
          input = dto.answers[question.id]
          # Le cahier n'a aucun champ : rien de ce qui est posté n'est lu, ni compté, ni noté.
          next unanswered(question) if input.nil? || question.kind::INPUT == :none

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

        return multi_blank_attempt(session, question, input) if multi_blank?(question)

        response = response_for(question, session, input)
        return [ nil, question.kind::INVALID ] unless question.well_formed?(response)
        return [ nil, { response_text: [ :too_long ] } ] if too_long_for_short_answer?(question, response)

        [ { question_id: question.id, selected_answer_ids: response.is_a?(String) ? [] : response,
            response_text: (response if response.is_a?(String)), correct: question.correct?(response), unanswered: false }, nil ]
      end

      def multi_blank?(question) = question.blanks > 1 && BLANK_KINDS.include?(question.kind)

      # Une question à plusieurs cases : une réponse par case, un verdict par case ; correct vaut « toutes les cases justes ».
      # response_text garde les réponses mises bout à bout (la ligne doit porter une réponse), sauf pour une liste, dont les
      # propositions choisies sont dans selected_answer_ids.
      def multi_blank_attempt(session, question, input)
        response = blank_response(question, session, input)
        return [ nil, question.kind::INVALID ] unless question.well_formed?(response)

        results = question.blank_results(response)
        texts = question.kind.respond_to?(:blank_texts) ? question.kind.blank_texts(question, response) : response
        select = question.kind.equal?(Entities::Assessment::QuestionKinds::Select)
        [ { question_id: question.id, selected_answer_ids: (response.compact if select) || [], response_text: (texts.join(BLANK_SEPARATOR) unless select),
            correct: results.all?, blank_responses: texts, blank_results: results, unanswered: false }, nil ]
      end

      # Un texte par case (chiffré, trous), ou l'identifiant de la proposition choisie dans chaque case (liste) : l'indice d'affichage
      # posté se relit dans le mélange de la session. Une case sautée est vide ; une case en trop reste, pour que la copie soit refusée.
      def blank_response(question, session, input)
        posted = input.blanks + Array.new([ question.blanks - input.blanks.size, 0 ].max, "")
        return posted unless question.kind.equal?(Entities::Assessment::QuestionKinds::Select)

        shuffled = Entities::Assessment::AnswerShuffle.for(session_id: session.id, question_id: question.id, ids: question.answer_ids)
        posted.map { |index| shown_id(shuffled, index) }
      end

      # Vide : la case est laissée vide (nil). Non vide, illisible ou hors bornes : INVALID_PICK, que well_formed? refuse.
      def shown_id(shuffled, index)
        return nil if index.strip.empty?

        at = index.match?(Dtos::Assessment::AttemptInput::INTEGER) ? index.to_i : nil
        at&.between?(0, shuffled.size - 1) ? shuffled[at] : INVALID_PICK
      end

      # Seule la réponse rédigée a droit à 2 000 caractères ; trous et nombre restent à 200 (menace W2).
      def too_long_for_short_answer?(question, response)
        question.kind::INPUT == :response_text && !question.kind.equal?(Entities::Assessment::QuestionKinds::Written) &&
          response.length > Dtos::Assessment::AttemptInput::RESPONSE_TEXT_MAX
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
        else
          shuffled = Entities::Assessment::AnswerShuffle.for(session_id: session.id, question_id: question.id, ids: question.answer_ids)
          Entities::Assessment::AnswerShuffle.select(shuffled, input.display_order)
        end
      end
    end
  end
end

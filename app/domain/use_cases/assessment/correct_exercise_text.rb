# 🧠 DOMAINE · UseCases::Assessment::CorrectExerciseText
# Rôle : l'équipe corrige à l'écran le texte d'un exercice, de ses questions et de ses propositions, et laquelle est juste, même déjà tentées ; questions et propositions ne s'ajoutent ni ne se retirent ; inscrit au journal
# ADR  : 0035, 0036 (une question tentée garde sa structure), 0113 (§4.6, amendement du 2026-11-14), 0115, 0116 · chantier edition-texte-lecon
module UseCases
  module Assessment
    class CorrectExerciseText
      # Le texte saisi. Les identifiants désignent les questions et propositions existantes, toutes et rien qu'elles.
      ExerciseText = Data.define(:title, :statement, :hint, :questions)
      QuestionText = Data.define(:id, :content, :explanation, :hint, :answers)
      AnswerText = Data.define(:id, :content, :match_content, :correct)

      # Types dont la bonne réponse se choisit parmi les propositions ; ailleurs, la proposition est la réponse (correct reste).
      KEYED_KINDS = [ Entities::Assessment::QuestionKinds::Choice, Entities::Assessment::QuestionKinds::Select ].freeze
      TEXT_MAX = 2_000
      HINT_MAX = 500
      ANSWER_MAX = 500

      def initialize(exercises:, audit_log:, transaction:, policy:, clock:)
        @exercises = exercises
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # Les tentatives passées gardent leur résultat (question_attempts.correct, scores) : rien n'est recalculé ; la nouvelle
      # bonne réponse vaut pour les tentatives suivantes (décision du porteur, 2026-11-14).
      # → Result(Exercise relu) | :forbidden | :not_found
      #   | :invalid (base: structure_changed ; title, statement, hint : codes ; :"questions.<n>" : codes de la question n)
      def call(actor:, public_id:, text:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        current = @exercises.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if current.nil?

        @transaction.call { correct(actor, current, text) }
      end

      private

      # Verrou puis relecture : la structure comparée est celle qui sera écrite (menace.md, n° 15).
      def correct(actor, current, text)
        @exercises.lock(id: current.id)
        exercise = @exercises.find_by_public_id(public_id: current.public_id)
        return invalid(base: [ :structure_changed ]) unless same_structure?(exercise, text)

        corrected = corrected_exercise(exercise, text)
        errors = exercise_errors(exercise, corrected).merge(question_errors(exercise, corrected))
        return invalid(**errors) if errors.any?

        at = @clock.now
        @exercises.correct_text(exercise: corrected)
        @audit_log.record(action: "content.corrected", actor_id: actor.user_id, at:, subject_type: "Exercise", subject_id: exercise.id,
                          metadata: { public_id: exercise.public_id, answer_key_changed: key_changes(exercise, corrected) })
        Shared::Result.success(@exercises.find_by_public_id(public_id: exercise.public_id))
      end

      def same_structure?(exercise, text)
        given = Array(text.questions)
        return false unless given.map(&:id).sort == exercise.questions.map(&:id).sort

        by_id = given.index_by(&:id)
        exercise.questions.all? { |question| Array(by_id[question.id].answers).map(&:id).sort == question.answer_ids.sort }
      end

      def corrected_exercise(exercise, text)
        by_id = text.questions.index_by(&:id)
        Entities::Assessment::Exercise.new(
          id: exercise.id, public_id: exercise.public_id, course_id: exercise.course_id, essential_id: exercise.essential_id,
          exercise_type: exercise.exercise_type, position: exercise.position, author_id: exercise.author_id, status: exercise.status,
          published_at: exercise.published_at, archived_at: exercise.archived_at, statement_blocks: exercise.statement_blocks,
          subject_id: exercise.subject_id, parents_published: exercise.parents_published,
          title: text.title, statement: text.statement, hint: text.hint,
          questions: exercise.questions.map { corrected_question(it, by_id.fetch(it.id)) }
        )
      end

      def corrected_question(question, given)
        answers_by_id = given.answers.index_by(&:id)
        keyed = KEYED_KINDS.include?(question.kind)
        question.with(
          content: given.content.to_s.strip, explanation: given.explanation.to_s.strip.presence, hint: given.hint.to_s.strip.presence,
          answers: question.answers.map do |answer|
            input = answers_by_id.fetch(answer.id)
            answer.with(content: input.content.to_s.strip, match_content: (input.match_content.to_s.strip.presence if answer.match_content),
                        correct: keyed ? input.correct == true : answer.correct)
          end
        )
      end

      # Le sujet est obligatoire s'il l'était (ADR-0113 §4.4) ; les bornes sont celles de l'entité.
      def exercise_errors(exercise, corrected)
        errors = {}
        corrected.valid?
        corrected.errors.each { |error| (errors[error.attribute] ||= []) << error.type }
        errors[:statement] = [ :blank ] if exercise.statement.present? && corrected.statement.nil?
        errors.slice(:title, :statement, :hint)
      end

      # Par question, numérotée à partir de 1 : textes vides ou trop longs, puis les règles de son type (ADR-0039, ADR-0115). Une
      # règle que la question cassait déjà à l'import ne bloque pas une coquille, sauf si la bonne réponse ou un texte relié change.
      def question_errors(exercise, corrected)
        corrected.questions.each_with_index.with_object({}) do |(question, index), errors|
          before = exercise.questions[index]
          codes = text_errors(question)
          codes += question.structure_errors - (key_or_match_changed?(before, question) ? [] : before.structure_errors) if codes.empty?
          errors[:"questions.#{index + 1}"] = codes.uniq if codes.any?
        end
      end

      def text_errors(question)
        codes = []
        codes << :content_blank if question.content.empty?
        codes << :too_long if question.content.length > TEXT_MAX || question.explanation.to_s.length > TEXT_MAX
        codes << :too_long if question.hint.to_s.length > HINT_MAX
        codes << :answer_blank if question.answers.any? { it.content.empty? }
        codes << :too_long if question.answers.any? { it.content.length > ANSWER_MAX || it.match_content.to_s.length > ANSWER_MAX }
        codes
      end

      def key_or_match_changed?(before, after)
        before.correct_answer_ids.sort != after.correct_answer_ids.sort || before.answers.map(&:match_content) != after.answers.map(&:match_content)
      end

      # Les questions dont la bonne réponse a changé, pour le journal. → [question_id]
      def key_changes(exercise, corrected)
        exercise.questions.zip(corrected.questions).filter_map do |before, after|
          before.id if before.correct_answer_ids.sort != after.correct_answer_ids.sort
        end
      end

      def invalid(**errors) = Shared::Result.failure(:invalid, errors:)
    end
  end
end

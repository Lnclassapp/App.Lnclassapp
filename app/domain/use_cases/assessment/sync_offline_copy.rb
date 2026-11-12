# 🧠 DOMAINE · UseCases::Assessment::SyncOfflineCopy
# Rôle : le serveur reçoit une copie rendue hors ligne, la vérifie (jeton, version, droits, pause), la recorrige seul et la range terminée ; une copie refusée n'écrit rien
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.5 ; menace P4, R1 à R6), 0026, 0033, 0043, 0054, 0115, 0120-questions-a-plusieurs-cases-et-indice (cases), 0121 (§4 ; amendé : la copie d'un devoir est rattachée au devoir), 0126 (garde d'accès)
module UseCases
  module Assessment
    class SyncOfflineCopy
      # session : l'ExerciseSession enregistrée (ou déjà enregistrée sous cet identifiant) ; already_synced : rien n'a été écrit cette fois.
      Synced = Data.define(:session, :already_synced)

      # Une tentative lue par Grading.share : le verdict, et celui de chaque case.
      Graded = Data.define(:correct, :blank_results)

      BLANK_KINDS = [ Entities::Assessment::QuestionKinds::Numeric, Entities::Assessment::QuestionKinds::FillBlank,
                      Entities::Assessment::QuestionKinds::Select ].freeze
      BLANK_SEPARATOR = " ; ".freeze
      INVALID_PICK = :invalid_pick

      def initialize(signer:, exercises:, sessions:, gaps:, badges:, memberships:, assignments:, policy:, transaction:, clock:, access:, current_digest:)
        @current_digest = current_digest
        @signer = signer
        @exercises = exercises
        @sessions = sessions
        @gaps = gaps
        @badges = badges
        @memberships = memberships
        @assignments = assignments
        @policy = policy
        @transaction = transaction
        @clock = clock
        @access = access
      end

      # current_digest : callable (exercise) → l'empreinte courante de l'exercice (Queries::Assessment::OfflinePackQuery.digest : celle que le paquet a signée ; un écart, l'exercice a changé, menace C3).
      # dto : Dtos::Assessment::OfflineCopyInput. Les droits sont jugés à l'heure de réception (clock), pas à l'heure d'origine.
      # → Result(Synced) | :forbidden (pas un élève ; errors base [:wrong_owner] : jeton d'un autre élève, d'un autre exercice ou altéré ;
      #   [:not_published] : exercice retiré) | :conflict (base [:stale] : exercice modifié ; [:paused] : 3 copies d'affilée)
      #   | :locked (base [:subscription_required]) | :invalid (copie illisible, question étrangère) | :not_found (exercice absent)
      def call(actor:, dto:)
        return Shared::Result.failure(:forbidden) unless actor&.student?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        pack = owned_pack(actor, dto)
        return pack if pack.is_a?(Shared::Result)

        existing = @sessions.find_by_client_copy_id(student_id: actor.user_id, client_copy_id: dto.client_copy_id)
        return synced(existing, already: true) if existing

        exercise = @exercises.find_by_public_id(public_id: dto.exercise_public_id)
        return Shared::Result.failure(:not_found) if exercise.nil?
        return Shared::Result.failure(:forbidden, errors: { base: [ :wrong_owner ] }) unless exercise.id == pack.fetch(:exercise_id)

        refused = refusal(actor, exercise, pack)
        return refused if refused

        @transaction.call { store(actor, exercise, pack, dto) }
      end

      private

      # → le contenu du jeton, ou un refus wrong_owner : signature fausse, autre élève, autre exercice.
      def owned_pack(actor, dto)
        pack = @signer.verify(dto.pack_token)
        return pack if pack && pack.fetch(:student_id) == actor.user_id
        return Shared::Result.failure(:forbidden, errors: { base: [ :expired ] }) if pack.nil? && @signer.expired?(dto.pack_token)

        Shared::Result.failure(:forbidden, errors: { base: [ :wrong_owner ] })
      end

      def synced(session, already:) = Shared::Result.success(Synced.new(session:, already_synced: already))

      # nil si la copie peut être rangée, sinon le refus (rien n'est écrit).
      def refusal(actor, exercise, pack)
        allowed = @policy.call(actor:, exercise:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:conflict, errors: { base: [ :stale ] }) unless @current_digest.call(exercise) == pack.fetch(:digest)

        now = @clock.now
        return Shared::Result.failure(:locked, errors: { base: [ :subscription_required ] }) if @access.call(student_id: actor.user_id, at: now).blocked?

        nil
      end

      # La pause des 3 copies, relue sous le verrou (élève, exercice) : deux envois en même temps ne passent pas tous deux la 3e copie.
      def pause_refusal(actor, exercise, now)
        @sessions.lock_restart_window(student_id: actor.user_id, exercise_id: exercise.id)
        completions = @sessions.recent_completions(student_id: actor.user_id, exercise_id: exercise.id)
        resume_at = Entities::Assessment::RestartPause.resume_at(completions:, now:)
        Shared::Result.failure(:conflict, errors: { base: [ :paused ], resume_at: }) if resume_at
      end

      def store(actor, exercise, pack, dto)
        paused = pause_refusal(actor, exercise, @clock.now)
        return paused if paused

        attempts = grade(exercise, dto)
        return attempts if attempts.failure?

        received_at = @clock.now
        session = build_session(actor, exercise, pack, dto, attempts.value, received_at)
        recorded = @sessions.record_offline_copy(session:, attempts: attempts.value, client_copy_id: dto.client_copy_id, received_at:)
        return replayed(actor, dto) if recorded == :duplicate

        settle(recorded, exercise, received_at)
        synced(recorded, already: false)
      end

      # Une course : l'autre envoi de la même copie a écrit entre notre lecture et notre écriture.
      def replayed(actor, dto)
        existing = @sessions.find_by_client_copy_id(student_id: actor.user_id, client_copy_id: dto.client_copy_id)
        existing ? synced(existing, already: true) : Shared::Result.failure(:conflict)
      end

      def build_session(actor, exercise, pack, dto, attempts, received_at)
        issued_at = pack.fetch(:issued_at)
        completed_at = Entities::Assessment::OfflineCopyWindow.clamp(time: dto.submitted_at, issued_at:, received_at:)
        started_at = [ Entities::Assessment::OfflineCopyWindow.clamp(time: dto.started_at, issued_at:, received_at:), completed_at ].min
        gap = @gaps.pending_for(student_id: actor.user_id, essential_id: exercise.essential_id)
        Entities::Assessment::ExerciseSession.new(
          id: nil, public_id: nil, student_id: actor.user_id, exercise_id: exercise.id, status: "completed", question_count: exercise.questions.size,
          answered_count: attempts.size, correct_count: attempts.count { it[:correct] }, progress_percent: 100,
          score_percent: score_percent(exercise, attempts), kind: gap ? "remediation" : "standard", knowledge_gap_id: gap&.id,
          classroom_assignment_id: assignment_id(actor, exercise), started_at:, completed_at:
        )
      end

      # La règle de CloseExerciseSession : seules les questions corrigées automatiquement, une question sans tentative est fausse.
      def score_percent(exercise, attempts)
        by_question = attempts.to_h { [ it.fetch(:question_id), Graded.new(correct: it[:correct], blank_results: it.fetch(:blank_results, [])) ] }
        graded = exercise.questions.select(&:auto_graded?).map { [ it.points, Entities::Assessment::Grading.share(it, by_question[it.id]) ] }
        Entities::Assessment::Grading.points_percent(graded)
      end

      # Rattachée à l'assignation active de l'exercice dans la classe principale de l'élève (ADR-0048), comme au démarrage en ligne, y
      # compris un devoir encore à rendre (décision du porteur, 2026-11-12) : la marque « corrigé reçu » se lit alors côté enseignant.
      def assignment_id(actor, exercise)
        membership = @memberships.primary_for(student_id: actor.user_id)
        return unless membership && membership.classroom_active?

        assignable = Entities::Classroom::Assignable.new(type: "Exercise", id: exercise.id, key: exercise.public_id)
        @assignments.active_for(classroom_id: membership.classroom_id, assignable:)&.id
      end

      # Les suites de la clôture en ligne (CloseExerciseSession) : médaille, lacune ouverte, comptée ou levée.
      def settle(session, exercise, now)
        score = session.score_percent
        attempts = @sessions.attempts(session_id: session.id)
        treated = attempts.any? { !it.unanswered } || exercise.questions.any? { it.kind::INPUT == :none }
        award(session, Entities::Assessment::Grading.session_medal(score, treated:), now)
        settle_gap(session, exercise.essential_id, score, now, treated:)
      end

      def award(session, level, now)
        current = @badges.find(student_id: session.student_id, exercise_id: session.exercise_id)
        return unless Entities::Assessment::Grading.upgrade?(current&.level, level)

        @badges.upsert(badge: Entities::Assessment::Badge.new(student_id: session.student_id, exercise_id: session.exercise_id,
                                                              session_id: session.id, level:, awarded_at: now))
      end

      def settle_gap(session, essential_id, score_percent, now, treated:)
        return if essential_id.nil?

        pending = @gaps.pending_for(student_id: session.student_id, essential_id:)
        decision = Entities::Assessment::GapDecision.call(score_percent:, pending_gap: pending, session_kind: session.kind, treated:)
        return if decision == :none
        return @gaps.open(student_id: session.student_id, essential_id:, source_session_id: session.id, at: now) if decision == :open
        return @gaps.increment(id: pending.id) if decision == :increment

        @gaps.resolve(id: pending.id, status: decision.to_s, session_id: session.id, at: now)
      end

      # Une tentative par question de l'exercice, dans l'ordre. Les indices d'affichage de l'appareil se rapportent au mélange dont la graine
      # est l'identifiant de l'exercice (le paquet porte cet ordre en clair). Une réponse mal formée n'est pas rangée par l'appareil : elle
      # compte non répondue ici ; une copie illisible ou une question étrangère refuse la copie entière (menace R5).
      def grade(exercise, dto)
        questions = exercise.questions
        form = dto.to_copy_input(session_public_id: dto.client_copy_id)
        return invalid_copy unless form.valid? && form.answers.size <= questions.size && (form.answers.keys - questions.map(&:id)).empty?

        Shared::Result.success(questions.map do |question|
          input = form.answers[question.id]
          (attempt_for(exercise, question, input) if input && question.kind::INPUT != :none) || unanswered(question)
        end)
      end

      def invalid_copy = Shared::Result.failure(:invalid, errors: { base: [ :invalid_copy ] })

      def unanswered(question)
        { question_id: question.id, selected_answer_ids: [], response_text: nil, correct: false, unanswered: true }
      end

      # → tentative | nil (réponse mal formée)
      def attempt_for(exercise, question, input)
        return unless input.valid?
        return multi_blank_attempt(exercise, question, input) if question.blanks > 1 && BLANK_KINDS.include?(question.kind)

        response = response_for(exercise, question, input)
        return unless question.well_formed?(response) && !too_long?(question, response)

        { question_id: question.id, selected_answer_ids: response.is_a?(String) ? [] : response,
          response_text: (response if response.is_a?(String)), correct: question.correct?(response), unanswered: false }
      end

      def multi_blank_attempt(exercise, question, input)
        select = question.kind.equal?(Entities::Assessment::QuestionKinds::Select)
        posted = input.blanks + Array.new([ question.blanks - input.blanks.size, 0 ].max, "")
        response = select ? posted.map { picked_id(exercise, question, it) } : posted
        return unless question.well_formed?(response)

        results = question.blank_results(response)
        texts = question.kind.respond_to?(:blank_texts) ? question.kind.blank_texts(question, response) : response
        { question_id: question.id, selected_answer_ids: (response.compact if select) || [], response_text: (texts.join(BLANK_SEPARATOR) unless select),
          correct: results.all?, blank_responses: texts, blank_results: results, unanswered: false }
      end

      # Le mélange de l'appareil : même graine que le paquet (identifiant de l'exercice), même règle que la copie en ligne.
      def shuffled(exercise, question, avoid: nil)
        Entities::Assessment::AnswerShuffle.for(session_id: exercise.id, question_id: question.id, ids: question.answer_ids, avoid:)
      end

      # Liste à cases : l'indice d'affichage de la proposition choisie (vide : case sautée ; illisible ou hors bornes : refusé par well_formed?).
      def picked_id(exercise, question, entry)
        return nil if entry.strip.empty?

        order = shuffled(exercise, question)
        at = entry.match?(Dtos::Assessment::AttemptInput::INTEGER) ? entry.to_i : nil
        at&.between?(0, order.size - 1) ? order[at] : INVALID_PICK
      end

      def response_for(exercise, question, input)
        case question.kind::INPUT
        when :response_text then input.response_text.to_s
        when :display_order
          Entities::Assessment::AnswerShuffle.pick(shuffled(exercise, question, avoid: question.ids_by_position), input.display_order)
        else Entities::Assessment::AnswerShuffle.select(shuffled(exercise, question), input.display_order)
        end
      end

      def too_long?(question, response)
        question.kind::INPUT == :response_text && !question.kind.equal?(Entities::Assessment::QuestionKinds::Written) &&
          response.length > Dtos::Assessment::AttemptInput::RESPONSE_TEXT_MAX
      end
    end
  end
end

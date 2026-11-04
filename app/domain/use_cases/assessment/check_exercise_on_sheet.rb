# 🧠 DOMAINE · UseCases::Assessment::CheckExerciseOnSheet
# Rôle : « Vérifier ma réponse » sur la feuille de la leçon : ouvre une session neuve, rend la copie et la ferme, en une seule transaction
# ADR  : 0121 (§4, §6), 0054, 0091 (§4.4), 0112, 0115 · UDR : 0149 §3
module UseCases
  module Assessment
    class CheckExerciseOnSheet
      # La graine de l'ordre d'affichage de la feuille (ordre, relier) : la même que PrepareSheetsQuery::SHEET_SEED, qui la montre avant
      # toute session. Un test les compare.
      SHEET_SEED = 0

      # Lève dans la transaction pour annuler la session ouverte quand la copie est refusée : rien ne reste, ni session, ni abandon.
      Rollback = Class.new(StandardError) do
        attr_reader :failure

        def initialize(failure)
          @failure = failure
          super("copie non rendue")
        end
      end

      # start : StartExerciseSession ; submit : SubmitExerciseCopy ; policy : StartSessionPolicy (un élève lit un exercice publié) ;
      # pending : PendingAssignmentRepositoryPort ; assignments, memberships : les ports de la classe, pour « Rendre à l'enseignant ».
      def initialize(start:, submit:, exercises:, policy:, pending:, assignments:, memberships:, transaction:)
        @start = start
        @policy = policy
        @submit = submit
        @exercises = exercises
        @pending = pending
        @assignments = assignments
        @memberships = memberships
        @transaction = transaction
      end

      # answers : { "<question_id>" => { display_order: [indices de la feuille], response_text: } } tel que posté par la feuille.
      # → Result(SubmitExerciseCopy::Submitted) | :not_found (exercice absent ou archivé) | :forbidden
      #   | :conflict (errors base [:paused] et resume_at, ADR-0115 ; base [:assigned_pending] : le devoir est à rendre depuis « Ma classe »,
      #     CA-17 ; base [:assignment_closed] : le devoir donné n'est plus à rendre ; base [:exercise_archived] | [:session_closed] |
      #     [:already_answered], rendus par la copie) | :invalid (copie illisible)
      # assignment_public_id : « Rendre à l'enseignant » depuis « Ma classe » (CA-16, memo Q17). Il faut que l'assignation soit active, de la
      #   classe principale de l'élève, qu'elle porte cet exercice et qu'elle ne soit pas déjà rendue (sinon :forbidden ou :conflict) ; la copie
      #   s'y rattache. Sans lui, la vérification est un entraînement : refusée tant que le devoir est à rendre (CA-17), jamais rattachée.
      def call(actor:, exercise_public_id:, answers:, assignment_public_id: nil)
        exercise = @exercises.find_by_public_id(public_id: exercise_public_id)
        return Shared::Result.failure(:not_found) if exercise.nil?

        allowed = @policy.call(actor:, exercise:)
        return Shared::Result.failure(:not_found) if allowed.errors.fetch(:base, []).include?(:not_published)
        return allowed if allowed.failure?

        handing_in = !assignment_public_id.nil?
        assignment = (@assignments.find_by_public_id(public_id: assignment_public_id) if handing_in)
        refusal = handing_in ? refuse_hand_in(actor, exercise, assignment) : refuse_practice(actor, exercise)
        return refusal if refusal

        rolled_back { @transaction.call { check(actor, exercise, answers, assignment) } }
      end

      private

      def rolled_back
        yield
      rescue Rollback => e
        e.failure
      end

      def refuse_practice(actor, exercise)
        Shared::Result.failure(:conflict, errors: { base: [ :assigned_pending ] }) if to_hand_in?(actor, exercise)
      end

      def refuse_hand_in(actor, exercise, assignment)
        membership = @memberships.primary_for(student_id: actor.user_id)
        return Shared::Result.failure(:forbidden) unless own_assignment?(assignment, membership, exercise.public_id)

        Shared::Result.failure(:conflict, errors: { base: [ :assignment_closed ] }) unless assignment.active? && membership.classroom_active? &&
                                                                                          to_hand_in?(actor, exercise)
      end

      def own_assignment?(assignment, membership, exercise_public_id)
        assignment && membership && assignment.classroom_id == membership.classroom_id && assignment.assignable.key == exercise_public_id
      end

      def to_hand_in?(actor, exercise)
        @pending.pending_exercise_public_ids(student_id: actor.user_id, exercise_public_ids: [ exercise.public_id ]).include?(exercise.public_id)
      end

      # assignment : le devoir vérifié (nil pour un entraînement).
      def check(actor, exercise, answers, assignment)
        started = @start.call(actor:, exercise_public_id: exercise.public_id, restart: true, attach_assignment: !assignment.nil?)
        return started if started.failure?

        # Le devoir a pu être retiré entre la vérification et l'ouverture : une copie « rendue » sans rattachement serait perdue pour l'enseignant.
        raise Rollback.new(Shared::Result.failure(:conflict, errors: { base: [ :assignment_closed ] })) if assignment && started.value.classroom_assignment_id != assignment.id

        dto = Dtos::Assessment::CopyInput.new(session_public_id: started.value.public_id,
                                              answers: in_session_order(exercise, started.value, answers))
        submitted = @submit.call(actor:, dto:)
        raise Rollback.new(submitted) if submitted.failure?

        submitted
      end

      # La feuille poste le rang de chaque proposition dans SON ordre ; la copie lit les indices de l'ordre de la session (AnswerShuffle,
      # ADR-0091 §4.4). Sans cette traduction, la bonne réponse serait corrigée à côté.
      def in_session_order(exercise, session, answers)
        return answers unless answers.is_a?(Hash)

        questions = exercise.questions.index_by { it.id.to_s }
        answers.to_h do |key, fields|
          question = questions[key.to_s]
          [ key, (question && fields.is_a?(Hash) ? reorder(question, session, fields) : fields) ]
        end
      end

      def reorder(question, session, fields)
        fields = fields.symbolize_keys
        posted = Array(fields[:display_order])
        return fields if posted.empty?

        sheet = sheet_order(question)
        indices = posted.map { Integer(it.to_s, 10, exception: false) }
        return fields unless indices.all? { it&.between?(0, sheet.size - 1) }

        here = session_order(question, session)
        fields.merge(display_order: indices.map { here.index(sheet.fetch(it)).to_s })
      end

      # Ordre et relier : le mélange de la graine de la feuille ; les autres types (choix, liste) : l'ordre des positions.
      def sheet_order(question)
        return question.ids_by_position unless question.kind::INPUT == :display_order

        Entities::Assessment::AnswerShuffle.for(session_id: SHEET_SEED, question_id: question.id, ids: question.answer_ids,
                                                avoid: question.ids_by_position)
      end

      # Comme SubmitExerciseCopy#response_for.
      def session_order(question, session)
        avoid = (question.ids_by_position if question.kind::INPUT == :display_order)
        Entities::Assessment::AnswerShuffle.for(session_id: session.id, question_id: question.id, ids: question.answer_ids, avoid:)
      end
    end
  end
end

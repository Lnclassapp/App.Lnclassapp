require "test_helper"

module UseCases
  module Assessment
    # CA-15 à CA-19 (ADR-0112) : la copie est lue, corrigée et notée en un envoi ; une question vide compte faux ; un second
    # envoi n'écrit rien ; une réponse illisible refuse la copie entière. Entrées hostiles : question étrangère, trop de
    # réponses, texte de plus de 200 caractères, octet nul, double envoi, copie d'autrui.
    class SubmitExerciseCopyTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 28, 12)
      Clock = Data.define(:now)
      STUDENT = Entities::Identity::Actor.new(user_id: 7, role: :student)
      Answer = Entities::Assessment::Answer
      Question = Entities::Assessment::Question

      class FakeSessions
        include Ports::Assessment::ExerciseSessionRepositoryPort

        attr_reader :copies, :locks

        def initialize(session)
          @session = session
          @copies = []
          @locks = []
        end

        def find_by_public_id(public_id:, lock: false)
          @locks << lock
          @session if @session.public_id == public_id
        end

        def record_copy(session_id:, attempts:, at:)
          return :duplicate if @copies.any?

          @copies << { session_id:, attempts:, at: }
          :ok
        end
      end

      class FakeExercises
        include Ports::Assessment::ExerciseRepositoryPort

        def initialize(exercise)
          @exercise = exercise
        end

        def find(id:) = (@exercise if @exercise.id == id)
      end

      class SpyClose
        attr_reader :calls

        def initialize(failing: false)
          @calls = []
          @failing = failing
        end

        def call(actor:, session:, essential_id:)
          @calls << [ actor, session.id, essential_id ]
          return Shared::Result.failure(:forbidden) if @failing

          Shared::Result.success(CloseExerciseSession::Row.new(score_percent: 50, badge_level: :bronze, earned_now: true))
        end
      end

      def choice(id, answers) = Question.new(id:, position: id, content: "Q#{id}", explanation: nil, question_type: "true_false",
                                             answers: answers.map { |answer_id, correct| Answer.new(id: answer_id, position: answer_id, content: "P", correct:) })

      def numeric(id) = Question.new(id:, position: id, content: "Q#{id}", explanation: nil, question_type: "numeric",
                                     answers: [ Answer.new(id: id * 10, position: 1, content: "42", correct: true) ])

      def exercise(essential_id: 9, status: "published")
        Entities::Assessment::Exercise.new(
          id: 40, public_id: "ExErCiCe000040", course_id: 3, essential_id:, title: "Thalès", exercise_type: "fixation", status:,
          parents_published: true, questions: [ choice(1, { 11 => true, 12 => false }), numeric(2), choice(3, { 31 => false, 32 => true }) ]
        )
      end

      def session(status: "started", student_id: 7)
        Entities::Assessment::ExerciseSession.new(
          id: 5, public_id: "SeSsIoN0000005", student_id:, exercise_id: 40, status:, question_count: 3, answered_count: 0,
          correct_count: 0, progress_percent: 0, score_percent: nil, kind: "standard", knowledge_gap_id: nil,
          classroom_assignment_id: nil, started_at: NOW - 60, completed_at: nil
        )
      end

      # Les indices d'affichage de la session 5 pour les propositions données (ADR-0091 §4.4) : jamais leurs identifiants.
      def shown(question_id, *answer_ids)
        ids = exercise.questions.find { it.id == question_id }.answer_ids
        shuffled = Entities::Assessment::AnswerShuffle.for(session_id: 5, question_id:, ids:)
        { display_order: answer_ids.map { shuffled.index(it).to_s } }
      end

      def submit(answers, actor: STUDENT, stored: session, exercise: exercise(), failing_close: false)
        @sessions = FakeSessions.new(stored)
        @close = SpyClose.new(failing: failing_close)
        @transaction = FakeTransaction.new
        @use_case = SubmitExerciseCopy.new(sessions: @sessions, exercises: FakeExercises.new(exercise),
                                           policy: Policies::Assessment::SubmitAttemptPolicy.new, close: @close,
                                           transaction: @transaction, clock: Clock.new(NOW))
        @use_case.call(actor:, dto: Dtos::Assessment::CopyInput.new(session_public_id: "SeSsIoN0000005", answers:))
      end

      test "CA-15 : une copie juste est corrigée, enregistrée en un envoi sous verrou, puis la session est close dans la même transaction" do
        result = submit({ "1" => shown(1, 11), "2" => { response_text: " 42 " }, "3" => shown(3, 31) })

        assert result.success?
        assert_equal [ false, 50 ], [ result.value.already_closed, result.value.closed.score_percent ]
        copy = @sessions.copies.sole
        assert_equal [ 5, NOW ], [ copy[:session_id], copy[:at] ]
        assert_equal [ [ 1, [ 11 ], nil, true, false ], [ 2, [], "42", true, false ], [ 3, [ 31 ], nil, false, false ] ],
                     copy[:attempts].map { [ it[:question_id], it[:selected_answer_ids], it[:response_text], it[:correct], it[:unanswered] ] }
        assert_equal [ [ STUDENT, 5, 9 ] ], @close.calls
        assert_equal [ true ], @sessions.locks
        assert_equal 1, @transaction.calls
      end

      test "CA-16 : une question absente, ou vide, compte fausse et sans réponse" do
        submit({ "1" => shown(1, 11), "2" => { response_text: "   " } })

        attempts = @sessions.copies.sole[:attempts]
        assert_equal [ [ 1, true, false ], [ 2, false, true ], [ 3, false, true ] ], attempts.map { [ it[:question_id], it[:correct], it[:unanswered] ] }
        assert_equal [ [], nil ], [ attempts[1][:selected_answer_ids], attempts[1][:response_text] ]
      end

      test "CA-16 : une copie entièrement vide est acceptée et vaut 0" do
        assert submit({}).success?
        assert_equal [ true, true, true ], @sessions.copies.sole[:attempts].map { it[:unanswered] }
      end

      test "CA-17 : un second envoi de la copie rendue réussit sans rien écrire ni rien clore" do
        result = submit({ "1" => shown(1, 11) }, stored: session(status: "completed"))

        assert result.success?
        assert_equal [ "SeSsIoN0000005", true, nil ], [ result.value.session_public_id, result.value.already_closed, result.value.closed ]
        assert_empty @sessions.copies
        assert_empty @close.calls
      end

      test "CA-17 : deux envois qui se suivent n'écrivent qu'une copie (doublon refusé par le repository)" do
        submit({ "1" => shown(1, 11) })
        again = @use_case.call(actor: STUDENT, dto: Dtos::Assessment::CopyInput.new(session_public_id: "SeSsIoN0000005", answers: {}))

        assert_equal :conflict, again.code
        assert_equal 1, @sessions.copies.size
        assert_equal 1, @close.calls.size
      end

      test "CA-18 : une réponse mal formée refuse toute la copie, erreurs rangées par numéro de question, rien n'est écrit" do
        result = submit({ "1" => shown(1, 11), "2" => { response_text: "abc" }, "3" => shown(3, 31, 32) })

        assert_equal :invalid, result.code
        assert_equal [ 2, 3 ], result.errors.keys
        assert_equal({ response_text: [ :not_a_number ] }, result.errors[2])
        assert_equal({ answer_ids: [ :wrong_selection ] }, result.errors[3])
        assert_empty @sessions.copies
        assert_empty @close.calls
      end

      test "menace : un texte de plus de 200 caractères, ou un octet nul, refuse la copie" do
        too_long = submit({ "2" => { response_text: "1" * 201 } })
        null_byte = submit({ "2" => { response_text: "4\u00002" } })

        assert_equal [ :invalid, { response_text: [ :too_long ] } ], [ too_long.code, too_long.errors[2] ]
        assert_equal [ :invalid, { response_text: [ :invalid ] } ], [ null_byte.code, null_byte.errors[2] ]
        assert_empty @sessions.copies
      end

      test "menace : l'identifiant d'une question étrangère à l'exercice refuse la copie" do
        result = submit({ "1" => shown(1, 11), "999" => shown(1, 11) })

        assert_equal [ :invalid, { base: [ :invalid_copy ] } ], [ result.code, result.errors ]
        assert_empty @sessions.copies
      end

      test "menace : plus de réponses que de questions, ou une clé qui n'est pas un nombre, refuse la copie" do
        many = submit(Array.new(4) { |index| [ (index + 1).to_s, shown(1, 11) ] }.to_h)
        key = submit({ "1; DROP" => shown(1, 11) })

        assert_equal [ :invalid, :invalid ], [ many.code, key.code ]
        assert_empty @sessions.copies
      end

      test "menace : la copie d'un autre élève, ou un autre rôle, est refusée : :forbidden, même déjà rendue" do
        other = Entities::Identity::Actor.new(user_id: 7, role: :teacher)

        assert_equal :forbidden, submit({}, stored: session(student_id: 8)).code
        assert_equal :forbidden, submit({}, stored: session(student_id: 8, status: "completed")).code
        assert_equal :forbidden, submit({}, actor: other).code
        assert_empty @sessions.copies
      end

      test "sans acteur : :forbidden, rien n'est écrit" do
        assert_equal :forbidden, submit({}, actor: nil).code
        assert_empty @sessions.copies
      end

      test "un refus de la policy autre que la session close est rendu tel quel, rien n'est écrit" do
        refusing = Object.new
        refusing.define_singleton_method(:call) { |actor:, session:| Shared::Result.failure(:forbidden) }
        sessions = FakeSessions.new(session)
        use_case = SubmitExerciseCopy.new(sessions:, exercises: FakeExercises.new(exercise), policy: refusing, close: SpyClose.new,
                                          transaction: FakeTransaction.new, clock: Clock.new(NOW))

        result = use_case.call(actor: STUDENT, dto: Dtos::Assessment::CopyInput.new(session_public_id: "SeSsIoN0000005", answers: {}))

        assert_equal [ :forbidden, {} ], [ result.code, result.errors.to_h ]
        assert_empty sessions.copies
      end

      test "un exercice disparu : :not_found, rien n'est écrit" do
        sessions = FakeSessions.new(session)
        gone = Object.new
        gone.define_singleton_method(:find) { |id:| nil }
        use_case = SubmitExerciseCopy.new(sessions:, exercises: gone, policy: Policies::Assessment::SubmitAttemptPolicy.new, close: SpyClose.new,
                                          transaction: FakeTransaction.new, clock: Clock.new(NOW))

        assert_equal :not_found, use_case.call(actor: STUDENT, dto: Dtos::Assessment::CopyInput.new(session_public_id: "SeSsIoN0000005", answers: {})).code
        assert_empty sessions.copies
      end

      test "une session abandonnée, ou un exercice archivé : :conflict, rien n'est écrit" do
        abandoned = submit({}, stored: session(status: "abandoned"))
        archived = submit({}, exercise: exercise(status: "archived"))

        assert_equal [ :conflict, { base: [ :session_closed ] } ], [ abandoned.code, abandoned.errors ]
        assert_equal [ :conflict, { base: [ :exercise_archived ] } ], [ archived.code, archived.errors ]
        assert_empty @sessions.copies
      end

      # La clôture refusée annule la transaction (l'exception la fait reculer) : aucune tentative ne reste sans session close.
      test "menace : une clôture qui échoue lève dans la transaction pour l'annuler, et rend son échec" do
        raised = []
        transaction = FakeTransaction.new
        transaction.define_singleton_method(:call) { |&block| super(&block) rescue (raised << $!; raise) }
        sessions = FakeSessions.new(session)
        use_case = SubmitExerciseCopy.new(sessions:, exercises: FakeExercises.new(exercise), policy: Policies::Assessment::SubmitAttemptPolicy.new,
                                          close: SpyClose.new(failing: true), transaction:, clock: Clock.new(NOW))

        result = use_case.call(actor: STUDENT, dto: Dtos::Assessment::CopyInput.new(session_public_id: "SeSsIoN0000005", answers: {}))

        assert_equal :forbidden, result.code
        assert_equal [ SubmitExerciseCopy::Rollback ], raised.map(&:class)
      end

      test "CA-21 : un exercice de toute la leçon clôt sans notion (essential_id nil)" do
        submit({}, exercise: exercise(essential_id: nil))

        assert_equal [ [ STUDENT, 5, nil ] ], @close.calls
      end

      # ADR-0115 : un devoir avec les trois nouveaux types (menace W2 à W4, W7).
      def devoir
        questions = [
          Question.new(id: 1, position: 1, content: "Les points sont ___.", explanation: nil, question_type: "select",
                       answers: [ Answer.new(id: 11, position: 1, content: "parallèles", correct: false),
                                  Answer.new(id: 12, position: 2, content: "alignés", correct: true),
                                  Answer.new(id: 13, position: 3, content: "proportionnelles", correct: false) ]),
          Question.new(id: 2, position: 2, content: "Justifie.", explanation: "Corrigé", question_type: "written", answers: [],
                       starter: "Non, car…", points: BigDecimal("2")),
          Question.new(id: 3, position: 3, content: "Trace sur ton cahier.", explanation: "Corrigé", question_type: "notebook", answers: [])
        ]
        Entities::Assessment::Exercise.new(id: 40, public_id: "ExErCiCe000040", course_id: 3, essential_id: 9, title: "Devoir",
                                           exercise_type: "evaluation", status: "published", parents_published: true, questions:)
      end

      def attempts_of(result_answers)
        submit(result_answers, exercise: devoir)
        @sessions.copies.sole[:attempts].to_h { [ it[:question_id], it ] }
      end

      test "ADR-0115 : un choix dans une liste poste l'indice d'affichage de la proposition ; il est corrigé comme un choix" do
        shuffled = Entities::Assessment::AnswerShuffle.for(session_id: 5, question_id: 1, ids: [ 11, 12, 13 ])

        right = attempts_of({ "1" => { display_order: [ shuffled.index(12).to_s ] } })[1]
        wrong = attempts_of({ "1" => { display_order: [ shuffled.index(11).to_s ] } })[1]

        assert_equal [ [ 12 ], true, false ], [ right[:selected_answer_ids], right[:correct], right[:unanswered] ]
        assert_equal [ [ 11 ], false, false ], [ wrong[:selected_answer_ids], wrong[:correct], wrong[:unanswered] ]
        assert_equal true, attempts_of({ "1" => { display_order: [ "" ] } })[1][:unanswered]
      end

      test "ADR-0115 : un identifiant de proposition (et non un indice) posté pour la liste est refusé" do
        result = submit({ "1" => { display_order: [ "99" ] } }, exercise: devoir)

        assert_equal [ :invalid, { answer_ids: [ :wrong_selection ] } ], [ result.code, result.errors[1] ]
        assert_empty @sessions.copies
      end

      test "CA-21 : une réponse rédigée de 2 000 caractères est gardée telle quelle, jamais corrigée" do
        text = "Non, car <b>AM/AB</b> ≠ AN/AC. " + ("é" * 1969)
        attempt = attempts_of({ "2" => { response_text: text } })[2]

        assert_equal 2000, text.length
        assert_equal [ [], text, false, false ], [ attempt[:selected_answer_ids], attempt[:response_text], attempt[:correct], attempt[:unanswered] ]
      end

      test "CA-22 menace W2 : 2 001 caractères refusent la copie entière, rien n'est écrit" do
        result = submit({ "2" => { response_text: "a" * 2001 } }, exercise: devoir)

        assert_equal [ :invalid, { response_text: [ :text_too_long ] } ], [ result.code, result.errors[2] ]
        assert_empty @sessions.copies
        assert_empty @close.calls
      end

      test "menace W3 : un octet nul dans une réponse rédigée refuse la copie" do
        result = submit({ "2" => { response_text: "a\0b" } }, exercise: devoir)

        assert_equal [ :invalid, { response_text: [ :invalid ] } ], [ result.code, result.errors[2] ]
        assert_empty @sessions.copies
      end

      test "menace W4 : un texte mal encodé est refusé, rien n'est écrit" do
        result = submit({ "2" => { response_text: "a\xFFb".dup.force_encoding(Encoding::UTF_8) } }, exercise: devoir)

        assert_equal [ :invalid, { response_text: [ :invalid ] } ], [ result.code, result.errors[2] ]
        assert_empty @sessions.copies
      end

      test "ADR-0115 : un texte à trous de plus de 200 caractères est refusé, rien n'est écrit ; 200 est accepté" do
        gap = Question.new(id: 2, position: 1, content: "Le point est ___.", explanation: nil, question_type: "fill_blank",
                           answers: [ Answer.new(id: 20, position: 1, content: "aligné", correct: true) ])
        texts = Entities::Assessment::Exercise.new(id: 40, public_id: "ExErCiCe000040", course_id: 3, essential_id: 9, title: "Trous",
                                                   exercise_type: "fixation", status: "published", parents_published: true, questions: [ gap ])

        refused = submit({ "2" => { response_text: "a" * 201 } }, exercise: texts)
        assert_equal [ :invalid, { response_text: [ :too_long ] } ], [ refused.code, refused.errors[1] ]
        assert_empty @sessions.copies

        accepted = submit({ "2" => { response_text: "a" * 200 } }, exercise: texts)
        assert accepted.success?
        assert_equal 200, @sessions.copies.sole[:attempts].sole[:response_text].length
      end

      test "ADR-0115 : au-delà de 200 caractères, une réponse courte (nombre, trous) reste refusée" do
        result = submit({ "2" => { response_text: "1" * 201 } }, exercise: exercise)

        assert_equal [ { response_text: [ :too_long ] } ], [ result.errors[2] ]
      end

      test "menace W7 : le début de phrase n'est jamais une réponse ; une zone vide est sans réponse" do
        attempt = attempts_of({})[2]

        assert_equal [ nil, [], true, false ], [ attempt[:response_text], attempt[:selected_answer_ids], attempt[:unanswered], attempt[:correct] ]
        blank = attempts_of({ "2" => { response_text: "   " } })[2]
        assert_equal [ nil, true ], [ blank[:response_text], blank[:unanswered] ]
      end

      test "ADR-0115 : le travail sur le cahier n'a pas de réponse : ce qui est posté est ignoré, aucun verdict" do
        attempt = attempts_of({ "3" => { response_text: "x" * 5000, answer_ids: [ "12" ], display_order: [ "0" ] } })[3]

        assert_equal [ [], nil, false ], [ attempt[:selected_answer_ids], attempt[:response_text], attempt[:correct] ]
        assert_equal 1, @close.calls.size
      end

      test "session inconnue : :not_found" do
        sessions = FakeSessions.new(session)
        use_case = SubmitExerciseCopy.new(sessions:, exercises: FakeExercises.new(exercise), policy: Policies::Assessment::SubmitAttemptPolicy.new,
                                          close: SpyClose.new, transaction: FakeTransaction.new, clock: Clock.new(NOW))

        assert_equal :not_found, use_case.call(actor: STUDENT, dto: Dtos::Assessment::CopyInput.new(session_public_id: "inconnue")).code
      end

      def two_select
        answers = [ Answer.new(id: 21, position: 1, content: "a", correct: true, blank: 0), Answer.new(id: 22, position: 2, content: "b", correct: false, blank: 0),
                    Answer.new(id: 23, position: 3, content: "c", correct: true, blank: 1), Answer.new(id: 24, position: 4, content: "d", correct: false, blank: 1) ]
        question = Question.new(id: 2, position: 1, content: "___ et ___", explanation: nil, question_type: "select", answers:)
        Entities::Assessment::Exercise.new(id: 40, public_id: "ExErCiCe000040", course_id: 3, essential_id: 9, title: "Listes",
                                           exercise_type: "fixation", status: "published", parents_published: true, questions: [ question ])
      end

      test "une liste à plusieurs cases : un indice non vide illisible ou hors bornes refuse la copie, une case vide reste vide" do
        shuffled = Entities::Assessment::AnswerShuffle.for(session_id: 5, question_id: 2, ids: [ 21, 22, 23, 24 ])
        right = shuffled.index(21).to_s

        [ "99", "-1", "abc" ].each do |bad|
          result = submit({ "2" => { blanks: { "0" => right, "1" => bad } } }, exercise: two_select)

          assert_equal [ :invalid, { answer_ids: [ :wrong_selection ] } ], [ result.code, result.errors[1] ], "saisie #{bad.inspect}"
          assert_empty @sessions.copies
        end

        result = submit({ "2" => { blanks: { "0" => right, "1" => "" } } }, exercise: two_select)
        attempt = @sessions.copies.sole[:attempts].sole

        assert result.success?, result.errors.inspect
        assert_equal [ [ true, false ], [ 21 ] ], [ attempt[:blank_results], attempt[:selected_answer_ids] ]
      end
    end
  end
end

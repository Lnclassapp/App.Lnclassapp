require "test_helper"

module UseCases
  module Assessment
    # hors-connexion, Lot C (CA-8 à CA-14, menace P4, R1 à R6) : une copie rendue hors ligne est vérifiée, recorrigée par le serveur
    # (aucune note envoyée n'est lue), bornée en heure, rejouée sans effet, et rien n'est écrit quand elle est refusée.
    class SyncOfflineCopyTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 12, 12)
      UUID = "3f2b8a1e-5c4d-4e6f-9a7b-1c2d3e4f5a6b".freeze
      Clock = Data.define(:now)
      Access = Data.define(:blocked) { def blocked? = blocked }

      class FakeAccess
        def initialize(blocked) = @blocked = blocked
        def call(student_id:, at:) = Access.new(@blocked)
      end

      # Le premier find_by_client_copy_id ne voit rien : l'autre requête n'a pas encore écrit (course concurrente).
      class RacingSessions < SimpleDelegator
        def find_by_client_copy_id(**)
          @raced ? super : (@raced = true; nil)
        end
      end

      class VanishingSessions < SimpleDelegator
        def record_offline_copy(**) = :duplicate
        def find_by_client_copy_id(**) = nil
      end

      setup do
        @exercise = create_exercise(questions: 2)
        @student = create_student_for(@exercise.course)
        @actor = Entities::Identity::Actor.new(user_id: @student.id, role: :student)
        @first, @second = @exercise.questions.order(:position).to_a
        @issued = NOW - 3600
        @signer = Repositories::Assessment::OfflinePackSigner.new
      end

      # L'appareil poste des indices d'affichage du mélange dont la graine est l'identifiant de l'exercice (paquet du Lot B).
      def shown(question, ids)
        order = Entities::Assessment::AnswerShuffle.for(session_id: @exercise.id, question_id: question.id, ids: question.answers.pluck(:id))
        Array(ids).map { order.index(it).to_s }
      end

      def right(question) = question.answers.find_by!(correct: true).id
      def wrong(question) = question.answers.where(correct: false).order(:id).first.id
      def pick(question, id) = { display_order: shown(question, id) }

      def digest = Queries::Assessment::OfflinePackQuery.new.call(public_id: @exercise.public_id).digest

      def token(student: @student, digest: self.digest, issued_at: @issued)
        @signer.sign(student_id: student.id, exercise_id: @exercise.id, digest:, issued_at:)
      end

      def payload(answers: nil, **overrides)
        answers ||= { @first.id.to_s => { **pick(@first, right(@first)) }, @second.id.to_s => { **pick(@second, wrong(@second)) } }
        { client_copy_id: UUID, exercise_public_id: @exercise.public_id, pack_token: token, started_at: (NOW - 1800).iso8601,
          submitted_at: (NOW - 600).iso8601, answers: }.merge(overrides)
      end

      def use_case(sessions: Repositories::Assessment::ExerciseSessionRepository.new, blocked: false)
        UseCases::Assessment::SyncOfflineCopy.new(
          signer: @signer, exercises: Repositories::Assessment::ExerciseRepository.new, sessions:,
          gaps: Repositories::Assessment::KnowledgeGapRepository.new, badges: Repositories::Assessment::BadgeRepository.new,
          memberships: Repositories::Classroom::MembershipRepository.new, assignments: Repositories::Classroom::AssignmentRepository.new,
          policy: Policies::Assessment::StartSessionPolicy.new, transaction: Repositories::Shared::Transaction.new,
          clock: Clock.new(NOW), access: FakeAccess.new(blocked),
          current_digest: ->(exercise) { Queries::Assessment::OfflinePackQuery.new.call(public_id: exercise.public_id).digest }
        )
      end

      def sync(attrs = payload, actor: @actor, **options)
        use_case(**options).call(actor:, dto: Dtos::Assessment::OfflineCopyInput.new(**attrs))
      end

      def assert_refused(result, code, reason = nil)
        assert_predicate result, :failure?
        assert_equal code, result.code
        assert_equal reason, result.errors.fetch(:base, []).first if reason
      end

      def assert_nothing_written(&)
        assert_no_difference([ "Orm::ExerciseSession.count", "Orm::QuestionAttempt.count", "Orm::ExerciseBadge.count" ], &)
      end

      test "CA-8 : la copie est corrigée par le serveur, terminée, avec l'heure d'origine et l'heure de réception" do
        result = sync

        assert_predicate result, :success?
        synced = result.value
        refute synced.already_synced
        row = Orm::ExerciseSession.find_by!(student_id: @student.id, client_copy_id: UUID)
        assert_equal [ "completed", 50, 1, 2 ], [ row.status, row.score_percent, row.correct_count, row.answered_count ]
        assert_equal [ NOW - 1800, NOW - 600, NOW ], [ row.started_at, row.completed_at, row.received_at ]
        assert_equal [ true, false ], row.question_attempts.order(:question_id).pluck(:correct)
        assert_equal synced.session.public_id, row.public_id
        assert_equal 50, synced.session.score_percent
      end

      test "la médaille de la copie est décernée comme à la clôture en ligne" do
        sync(payload(answers: { @first.id.to_s => { **pick(@first, right(@first)) }, @second.id.to_s => { **pick(@second, right(@second)) } }))

        assert_equal 100, Orm::ExerciseSession.find_by!(client_copy_id: UUID).score_percent
        assert Orm::ExerciseBadge.exists?(student_id: @student.id, exercise_id: @exercise.id)
      end

      test "CA-9 : le même envoi deux fois rend already_synced avec la copie existante, sans rien écrire" do
        first = sync.value

        assert_nothing_written do
          again = sync

          assert_predicate again, :success?
          assert again.value.already_synced
          assert_equal first.session.public_id, again.value.session.public_id
        end
      end

      test "CA-9 : deux envois en même temps n'écrivent qu'une copie" do
        sync
        raced = RacingSessions.new(Repositories::Assessment::ExerciseSessionRepository.new)

        assert_nothing_written do
          result = use_case(sessions: raced).call(actor: @actor, dto: Dtos::Assessment::OfflineCopyInput.new(**payload))

          assert_predicate result, :success?
          assert result.value.already_synced
        end
      end

      test "CA-9 : un rejeu reste already_synced même si l'exercice a changé depuis" do
        sync
        @first.update!(content: "<p>Autre énoncé</p>")

        assert sync.value.already_synced
      end

      test "CA-10 : une note envoyée (score, provisional_percent) n'est jamais lue" do
        sync(payload(score: 100, provisional_percent: 100, status: "synced"))

        assert_equal 50, Orm::ExerciseSession.find_by!(client_copy_id: UUID).score_percent
      end

      test "CA-11 : le jeton d'un autre élève est refusé wrong_owner, rien n'est écrit" do
        other = create_student_for(@exercise.course)

        assert_nothing_written { assert_refused sync(payload(pack_token: token(student: other)), actor: @actor), :forbidden, :wrong_owner }
      end

      test "F4 : un jeton de plus de 30 jours est refusé expired" do
        old = nil
        travel_to(NOW - 31.days) { old = token(issued_at: NOW - 31.days) }

        assert_nothing_written { assert_refused sync(payload(pack_token: old)), :forbidden, :expired }
      end

      test "CA-11 : un jeton altéré est refusé wrong_owner" do
        assert_nothing_written { assert_refused sync(payload(pack_token: "#{token}x")), :forbidden, :wrong_owner }
      end

      test "le jeton d'un autre exercice est refusé" do
        other = create_exercise(questions: 1)
        foreign = @signer.sign(student_id: @student.id, exercise_id: other.id, digest:, issued_at: @issued)

        assert_nothing_written { assert_refused sync(payload(pack_token: foreign)), :forbidden, :wrong_owner }
      end

      test "un compte qui n'est pas élève est refusé" do
        teacher = Entities::Identity::Actor.new(user_id: @student.id, role: :teacher)

        assert_nothing_written { assert_refused sync(actor: teacher), :forbidden }
      end

      # Couverture (ADR-0024) : chaque chemin du use case a sa preuve.
      test "sans compte, la copie est refusée forbidden" do
        assert_nothing_written { assert_refused sync(actor: nil), :forbidden }
      end

      test "un exercice qui n'existe plus refuse la copie not_found" do
        assert_nothing_written { assert_refused sync(payload(exercise_public_id: "absent0000000x")), :not_found }
      end

      test "une copie annoncée en double mais introuvable ensuite est refusée conflict" do
        sessions = VanishingSessions.new(Repositories::Assessment::ExerciseSessionRepository.new)

        assert_refused sync(sessions:), :conflict
      end

      test "une classe principale archivée : la copie est rangée sans rattachement" do
        classroom = Orm::ClassroomStudent.find_by!(student_id: @student.id).classroom
        create_assignment(classroom:, assignable: @exercise)
        classroom.update_columns(status: "archived", archived_at: NOW)

        assert_predicate sync, :success?
        assert_nil Orm::ExerciseSession.find_by!(client_copy_id: UUID).classroom_assignment_id
      end

      test "un devoir déjà rendu en ligne : la copie hors ligne est rattachée à son assignation" do
        classroom = Orm::ClassroomStudent.find_by!(student_id: @student.id).classroom
        assignment = create_assignment(classroom:, assignable: @exercise)
        create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 50, classroom_assignment: assignment,
                                completed_at: NOW - 3.hours)

        assert_predicate sync, :success?
        assert_equal assignment.id, Orm::ExerciseSession.find_by!(client_copy_id: UUID).classroom_assignment_id
      end

      test "une lacune en attente est levée par une copie à l'Or, comme à la clôture en ligne" do
        gap = create_gap(student: @student, essential: @exercise.essential)
        answers = { @first.id.to_s => pick(@first, right(@first)), @second.id.to_s => pick(@second, right(@second)) }

        assert_predicate sync(payload(answers:)), :success?
        assert_equal "remediated", gap.reload.status
        assert_equal Orm::ExerciseSession.find_by!(client_copy_id: UUID).id, gap.resolved_by_session_id
      end

      test "une réponse au texte illisible compte non répondue, la copie est rangée" do
        answers = { @first.id.to_s => { response_text: "\xFF".dup.force_encoding("UTF-8") }, @second.id.to_s => pick(@second, right(@second)) }

        assert_predicate sync(payload(answers:)), :success?
        first = Orm::QuestionAttempt.joins(:exercise_session).find_by!(exercise_sessions: { client_copy_id: UUID }, question_id: @first.id)
        assert first.unanswered
      end

      test "un exercice de toute la leçon, sans notion : la copie est rangée sans toucher aux lacunes" do
        @exercise = create_exercise(lesson_wide: true, course: @exercise.course)
        @first, @second = @exercise.questions.order(:position).to_a

        assert_predicate sync, :success?
        assert_equal 0, Orm::KnowledgeGap.where(student_id: @student.id).count
      end

      test "CA-12 : une heure d'origine dans le futur est ramenée à la réception" do
        sync(payload(started_at: (NOW + 3600).iso8601, submitted_at: (NOW + 7200).iso8601))

        row = Orm::ExerciseSession.find_by!(client_copy_id: UUID)
        assert_equal [ NOW, NOW ], [ row.started_at, row.completed_at ]
      end

      test "CA-12 : une heure de plus de 30 jours est ramenée à la borne, celle d'avant le paquet à l'émission" do
        old_token = token(issued_at: NOW - 40 * 86_400)
        sync(payload(pack_token: old_token, started_at: (NOW - 45 * 86_400).iso8601, submitted_at: (NOW - 31 * 86_400).iso8601))

        row = Orm::ExerciseSession.find_by!(client_copy_id: UUID)
        assert_equal [ NOW - 30 * 86_400, NOW - 30 * 86_400 ], [ row.started_at, row.completed_at ]
      end

      test "CA-12 : une heure avant l'émission du paquet est ramenée à l'émission" do
        sync(payload(started_at: (NOW - 7200).iso8601, submitted_at: (NOW - 7000).iso8601))

        row = Orm::ExerciseSession.find_by!(client_copy_id: UUID)
        assert_equal [ @issued, @issued ], [ row.started_at, row.completed_at ]
      end

      test "CA-13 : l'accès bloqué à la réception refuse la copie locked" do
        assert_nothing_written { assert_refused sync(blocked: true), :locked, :subscription_required }
      end

      test "CA-13 : un exercice dépublié refuse la copie forbidden" do
        @exercise.update_columns(status: "draft")

        assert_nothing_written { assert_refused sync, :forbidden, :not_published }
      end

      test "CA-13 : un exercice modifié depuis l'émission du paquet refuse la copie stale" do
        stale = token
        @first.answers.first.update!(content: "Proposition modifiée")

        assert_nothing_written { assert_refused sync(payload(pack_token: stale)), :conflict, :stale }
      end

      test "CA-14 : la 4e copie d'affilée est refusée paused, rien n'est écrit" do
        3.times do |index|
          create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 50,
                                  completed_at: NOW - (20 - index * 5) * 60)
        end

        assert_nothing_written { assert_refused sync, :conflict, :paused }
      end

      test "R5 : une question d'un autre exercice refuse la copie invalid" do
        stranger = create_exercise(questions: 1).questions.first
        answers = { stranger.id.to_s => { display_order: [ "0" ] } }

        assert_nothing_written { assert_refused sync(payload(answers:)), :invalid }
      end

      test "une réponse mal formée n'est pas rangée par l'appareil : elle compte non répondue, la copie est rangée" do
        answers = { @first.id.to_s => { display_order: %w[0 1 2 3] }, @second.id.to_s => pick(@second, right(@second)) }

        sync(payload(answers:))

        assert_equal [ false, true ], attempt_of(@first).then { [ it.correct, it.unanswered ] }
        assert_equal 50, Orm::ExerciseSession.find_by!(client_copy_id: UUID).score_percent
      end

      test "l'empreinte courante est injectée : l'empreinte fournie décide du stale" do
        sessions = Repositories::Assessment::ExerciseSessionRepository.new
        use_case = UseCases::Assessment::SyncOfflineCopy.new(
          signer: @signer, exercises: Repositories::Assessment::ExerciseRepository.new, sessions:,
          gaps: Repositories::Assessment::KnowledgeGapRepository.new, badges: Repositories::Assessment::BadgeRepository.new,
          memberships: Repositories::Classroom::MembershipRepository.new, assignments: Repositories::Classroom::AssignmentRepository.new,
          policy: Policies::Assessment::StartSessionPolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Clock.new(NOW),
          access: FakeAccess.new(false), current_digest: ->(_exercise) { "ailleurs" }
        )

        assert_nothing_written do
          assert_refused use_case.call(actor: @actor, dto: Dtos::Assessment::OfflineCopyInput.new(**payload)), :conflict, :stale
        end
      end

      test "R5 : un identifiant ou une heure illisible refuse la copie" do
        assert_nothing_written do
          assert_refused sync(payload(client_copy_id: "pas-un-uuid")), :invalid
          assert_refused sync(payload(submitted_at: "hier")), :invalid
        end
      end

      test "une question laissée sans réponse compte fausse et sans réponse" do
        sync(payload(answers: { @first.id.to_s => { **pick(@first, right(@first)) } }))

        attempt = Orm::QuestionAttempt.find_by!(question_id: @second.id)
        assert_equal [ false, true ], [ attempt.correct, attempt.unanswered ]
      end

      test "un devoir à rendre assigné depuis l'émission du jeton : la copie est rattachée au devoir (la marque se lit côté enseignant)" do
        classroom = Orm::ClassroomStudent.find_by!(student_id: @student.id).classroom
        assignment = create_assignment(classroom:, assignable: @exercise)
        attrs = payload(pack_token: token(issued_at: NOW - 2.days))

        result = sync(attrs)

        assert_predicate result, :success?
        assert_not result.value.already_synced
        assert_equal assignment.id, Orm::ExerciseSession.find_by!(client_copy_id: UUID).classroom_assignment_id
      end

      test "S2 : la pause est relue sous le verrou de l'élève et de l'exercice, dans la transaction de l'écriture" do
        calls = []
        locking = Class.new(SimpleDelegator) do
          define_method(:lock_restart_window) { |**args| calls << [ :lock, args ]; super(**args) }
          define_method(:recent_completions) { |**args| calls << [ :read, args ]; super(**args) }
        end

        assert_predicate sync(sessions: locking.new(Repositories::Assessment::ExerciseSessionRepository.new)), :success?

        assert_equal :lock, calls.first.first
        assert_equal({ student_id: @student.id, exercise_id: @exercise.id }, calls.first.last)
        assert_equal :read, calls.last.first
      end

      # Les autres types : numérique, ordre, réponse rédigée, cahier, trous, listes à plusieurs cases (même correction qu'en ligne).
      def add_question(type, answers, content: "Question #{type}")
        position = @exercise.questions.maximum(:position) + 1
        @exercise.questions.create!(position:, content:, question_type: type).tap do |question|
          answers.each_with_index { |(text, correct, blank), rank| question.answers.create!(position: rank + 1, content: text, correct:, blank: blank || 0) }
        end
      end

      def only(**answers) = answers.transform_keys(&:to_s).merge(@first.id.to_s => { **pick(@first, right(@first)) }, @second.id.to_s => { **pick(@second, right(@second)) })

      def attempt_of(question) = Orm::QuestionAttempt.find_by!(question_id: question.id)

      test "un nombre juste est corrigé, un texte trop long compte non répondu" do
        numeric = add_question("numeric", [ [ "42", true ] ])

        sync(payload(answers: only(numeric.id => { response_text: "42" })))

        assert_equal [ true, "42" ], attempt_of(numeric).then { [ it.correct, it.response_text ] }
        sync(payload(client_copy_id: SecureRandom.uuid, answers: only(numeric.id => { response_text: "9" * 201 })))

        assert_equal [ 2, true ], Orm::QuestionAttempt.where(question_id: numeric.id).order(:id).last(1).then { [ Orm::QuestionAttempt.where(question_id: numeric.id).count, it.first.unanswered ] }
      end

      test "un ordre est corrigé sur les identifiants dans l'ordre de l'élève" do
        ordering = add_question("ordering", [ [ "a", true ], [ "b", true ], [ "c", true ] ])
        ids = ordering.answers.order(:position).pluck(:id)

        order = Entities::Assessment::AnswerShuffle.for(session_id: @exercise.id, question_id: ordering.id, ids: ordering.answers.pluck(:id), avoid: ids)
        sync(payload(answers: only(ordering.id => { display_order: ids.reverse.map { order.index(it).to_s } })))

        assert_equal [ false, ids.reverse ], attempt_of(ordering).then { [ it.correct, it.selected_answer_ids ] }
      end

      test "une réponse rédigée est gardée sans note ; le cahier n'a aucun champ" do
        written = add_question("written", [])
        notebook = add_question("notebook", [])

        sync(payload(answers: only(written.id => { response_text: "Ma réponse" }, notebook.id => { response_text: "ignoré" })))

        assert_equal "Ma réponse", attempt_of(written).response_text
        assert_equal [ true, nil ], attempt_of(notebook).then { [ it.unanswered, it.response_text ] }
        assert_equal 100, Orm::ExerciseSession.find_by!(client_copy_id: UUID).score_percent
      end

      test "des trous à plusieurs cases : un verdict par case" do
        fill = add_question("fill_blank", [ [ "un", true, 0 ], [ "deux", true, 1 ] ])

        sync(payload(answers: only(fill.id => { blanks: { "0" => "un", "1" => "faux" } })))

        assert_equal [ [ true, false ], "un ; faux" ], attempt_of(fill).then { [ it.blank_results, it.response_text ] }
        assert_equal 83, Orm::ExerciseSession.find_by!(client_copy_id: UUID).score_percent
      end

      test "des listes à plusieurs cases : l'identifiant choisi dans chaque case, une case sautée reste vide" do
        select = add_question("select", [ [ "a", true, 0 ], [ "b", false, 0 ], [ "c", true, 1 ], [ "d", false, 1 ] ])
        ids = select.answers.order(:position).pluck(:id)

        sync(payload(answers: only(select.id => { blanks: { "0" => shown(select, ids[0]).first, "1" => "" } })))

        assert_equal [ [ true, false ], [ ids[0] ] ], attempt_of(select).then { [ it.blank_results, it.selected_answer_ids ] }
      end

      test "une liste dont l'indice est hors bornes n'est pas rangée : non répondue" do
        select = add_question("select", [ [ "a", true, 0 ], [ "b", false, 0 ], [ "c", true, 1 ], [ "d", false, 1 ] ])

        sync(payload(answers: only(select.id => { blanks: { "0" => "9", "1" => "abc" } })))

        assert_equal [ false, true ], attempt_of(select).then { [ it.correct, it.unanswered ] }
      end
    end
  end
end

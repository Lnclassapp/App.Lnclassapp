# 🔌 INFRA · Repositories::Assessment::ExerciseSessionRepository
# Rôle : sessions d'exercice et tentatives immuables ; compteurs tenus en SQL, une seule session ouverte par exercice
# ADR  : 0033, 0043, 0054, 0091, 0112, 0115, XXXX-questions-a-plusieurs-cases-et-indice (§4 : cases, indice ouvert)
module Repositories
  module Assessment
    class ExerciseSessionRepository
      include Ports::Assessment::ExerciseSessionRepositoryPort

      COUNTERS_SQL = <<~SQL.squish.freeze
        answered_count = answered_count + 1, correct_count = correct_count + ?,
        progress_percent = LEAST(100, ((answered_count + 1) * 100) / question_count), updated_at = ?
      SQL

      COPY_COUNTERS_SQL = <<~SQL.squish.freeze
        answered_count = answered_count + ?, correct_count = correct_count + ?,
        progress_percent = LEAST(100, ((answered_count + ?) * 100) / NULLIF(question_count, 0)), updated_at = ?
      SQL

      def find_by_public_id(public_id:, lock: false)
        scope = lock ? Orm::ExerciseSession.lock : Orm::ExerciseSession
        record = scope.find_by(public_id:)
        record && map_to_entity(record)
      end

      def started_for(student_id:, exercise_id:)
        record = Orm::ExerciseSession.find_by(student_id:, exercise_id:, status: "started")
        record && map_to_entity(record)
      end

      # L'index partiel refuse une seconde session ouverte : on renvoie celle qui existe.
      # Si la violation vient d'ailleurs (public_id déjà pris) ou si la session concurrente n'est plus ouverte, il n'y a rien à
      # renvoyer : l'exception d'origine remonte (500 gérée) plutôt qu'un nil que l'appelant prendrait pour une session.
      def start(session:)
        record = Orm::ExerciseSession.new(
          public_id: session.public_id, student_id: session.student_id, exercise_id: session.exercise_id, status: "started",
          question_count: session.question_count, kind: session.kind, knowledge_gap_id: session.knowledge_gap_id,
          classroom_assignment_id: session.classroom_assignment_id, started_at: session.started_at
        )
        # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case.
        Orm::ExerciseSession.transaction(requires_new: true) { record.save! }
        map_to_entity(record)
      rescue ActiveRecord::RecordNotUnique
        started_for(student_id: session.student_id, exercise_id: session.exercise_id) || raise
      end

      def abandon(id:, at:)
        Orm::ExerciseSession.where(id:, status: "started").update_all(status: "abandoned", updated_at: at)
        true
      end

      # La copie entière, une tentative par question, et les compteurs de la session, dans un savepoint.
      # Une copie commencée en répondant question par question garde ses tentatives : seules les questions sans tentative s'écrivent.
      def record_copy(session_id:, attempts:, at:)
        Orm::QuestionAttempt.transaction(requires_new: true) do
          answered = Orm::QuestionAttempt.where(exercise_session_id: session_id).pluck(:question_id)
          written = attempts.reject { answered.include?(it.fetch(:question_id)) }
          written.each do |attempt|
            Orm::QuestionAttempt.create!(exercise_session_id: session_id, question_id: attempt.fetch(:question_id),
                                         selected_answer_ids: attempt.fetch(:selected_answer_ids), response_text: attempt[:response_text],
                                         correct: attempt.fetch(:correct), unanswered: attempt.fetch(:unanswered, false), answered_at: at,
                                         blank_responses: attempt.fetch(:blank_responses, []), blank_results: attempt.fetch(:blank_results, []))
          end
          Orm::ExerciseSession.where(id: session_id).update_all([ COPY_COUNTERS_SQL, written.size, written.count { it[:correct] }, written.size, at ])
        end
        :ok
      rescue ActiveRecord::RecordNotUnique
        :duplicate
      end

      # L'ouverture d'un indice : array_append seulement si la question n'y est pas, dans un seul UPDATE (il verrouille la ligne de la
      # session), donc dix ouvertures donnent une seule mention, même concurrentes.
      def record_hint(session_id:, question_id:)
        opened = Orm::ExerciseSession.where(id: session_id).where("NOT (? = ANY(hinted_question_ids))", question_id)
                                     .update_all([ "hinted_question_ids = array_append(hinted_question_ids, ?)", question_id ])
        opened.positive? ? :recorded : :already_opened
      end

      def record_attempt(session_id:, question_id:, selected_answer_ids:, correct:, at:, response_text: nil)
        # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case.
        Orm::QuestionAttempt.transaction(requires_new: true) do
          Orm::QuestionAttempt.create!(exercise_session_id: session_id, question_id:, selected_answer_ids:, response_text:, correct:,
                                       answered_at: at)
        end
        Orm::ExerciseSession.where(id: session_id).update_all([ COUNTERS_SQL, correct ? 1 : 0, at ])
        :recorded
      rescue ActiveRecord::RecordNotUnique
        :duplicate
      end

      def attempts(session_id:)
        Orm::QuestionAttempt.where(exercise_session_id: session_id).order(:answered_at, :id).map do |record|
          Entities::Assessment::QuestionAttempt.new(session_id: record.exercise_session_id, question_id: record.question_id,
                                                    selected_answer_ids: record.selected_answer_ids, correct: record.correct,
                                                    answered_at: record.answered_at, response_text: record.response_text,
                                                    blank_responses: record.blank_responses, blank_results: record.blank_results)
        end
      end

      def recent_completions(student_id:, exercise_id:)
        Orm::ExerciseSession.where(student_id:, exercise_id:, status: "completed").where.not(completed_at: nil)
                            .order(completed_at: :desc).limit(Entities::Assessment::RestartPause::STREAK).pluck(:completed_at)
      end

      # Une seule requête : ROW_NUMBER() par exercice, on garde les `limit` premières fins.
      def recent_completions_by_exercise(student_id:, exercise_ids:, limit: Entities::Assessment::RestartPause::STREAK)
        return {} if exercise_ids.empty?

        ranked = Orm::ExerciseSession.where(student_id:, exercise_id: exercise_ids, status: "completed").where.not(completed_at: nil)
                                     .select("exercise_id, completed_at, ROW_NUMBER() OVER (PARTITION BY exercise_id ORDER BY completed_at DESC) AS rank")
        Orm::ExerciseSession.unscoped.from(ranked, :ranked).where("ranked.rank <= ?", limit)
                            .order("ranked.exercise_id", "ranked.completed_at DESC").pluck("ranked.exercise_id", "ranked.completed_at")
                            .group_by(&:first).transform_values { |rows| rows.map(&:last) }
      end

      def complete(id:, score_percent:, at:)
        Orm::ExerciseSession.where(id:, status: "started")
                            .update_all(status: "completed", score_percent:, completed_at: at, updated_at: at)
        true
      end

      private

      def map_to_entity(record)
        Entities::Assessment::ExerciseSession.new(
          id: record.id, public_id: record.public_id, student_id: record.student_id, exercise_id: record.exercise_id,
          status: record.status, question_count: record.question_count, answered_count: record.answered_count,
          correct_count: record.correct_count, progress_percent: record.progress_percent, score_percent: record.score_percent,
          kind: record.kind, knowledge_gap_id: record.knowledge_gap_id, classroom_assignment_id: record.classroom_assignment_id,
          started_at: record.started_at, completed_at: record.completed_at, hinted_question_ids: record.hinted_question_ids
        )
      end
    end
  end
end

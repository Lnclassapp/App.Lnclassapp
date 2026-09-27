# 🔌 INFRA · Repositories::Assessment::ExerciseSessionRepository
# Rôle : sessions d'exercice et tentatives immuables ; compteurs tenus en SQL, une seule session ouverte par exercice
# ADR  : 0033, 0043, 0054
module Repositories
  module Assessment
    class ExerciseSessionRepository
      include Ports::Assessment::ExerciseSessionRepositoryPort

      COUNTERS_SQL = <<~SQL.squish.freeze
        answered_count = answered_count + 1, correct_count = correct_count + ?,
        progress_percent = LEAST(100, ((answered_count + 1) * 100) / question_count), updated_at = ?
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
        started_for(student_id: session.student_id, exercise_id: session.exercise_id)
      end

      def abandon(id:, at:)
        Orm::ExerciseSession.where(id:, status: "started").update_all(status: "abandoned", updated_at: at)
        true
      end

      def record_attempt(session_id:, question_id:, selected_answer_ids:, correct:, at:)
        # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case.
        Orm::QuestionAttempt.transaction(requires_new: true) do
          Orm::QuestionAttempt.create!(exercise_session_id: session_id, question_id:, selected_answer_ids:, correct:,
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
                                                    answered_at: record.answered_at)
        end
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
          started_at: record.started_at, completed_at: record.completed_at
        )
      end
    end
  end
end

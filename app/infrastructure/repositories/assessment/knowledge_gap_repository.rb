# 🔌 INFRA · Repositories::Assessment::KnowledgeGapRepository
# Rôle : lacunes d'un élève sur une fiche ; une seule en attente par couple, garantie par l'index partiel
# ADR  : 0043
module Repositories
  module Assessment
    class KnowledgeGapRepository
      include Ports::Assessment::KnowledgeGapRepositoryPort

      def pending_for(student_id:, essential_id:)
        record = Orm::KnowledgeGap.find_by(student_id:, essential_id:, status: "pending")
        record && map_to_entity(record)
      end

      def find(id:)
        record = Orm::KnowledgeGap.find_by(id:)
        record && map_to_entity(record)
      end

      # Deux clôtures concurrentes : la seconde heurte l'index et reçoit la lacune ouverte par la première.
      def open(student_id:, essential_id:, source_session_id:, at:)
        record = Orm::KnowledgeGap.new(student_id:, essential_id:, source_session_id:, status: "pending",
                                       failed_sessions_count: 1, created_at: at, updated_at: at)
        # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case.
        Orm::KnowledgeGap.transaction(requires_new: true) { record.save! }
        map_to_entity(record)
      rescue ActiveRecord::RecordNotUnique
        pending_for(student_id:, essential_id:)
      end

      def increment(id:)
        Orm::KnowledgeGap.where(id:).update_all("failed_sessions_count = failed_sessions_count + 1")
        true
      end

      def resolve(id:, status:, session_id:, at:)
        Orm::KnowledgeGap.where(id:, status: "pending")
                         .update_all(status:, resolved_by_session_id: session_id, resolved_at: at, updated_at: at)
        true
      end

      private

      def map_to_entity(record)
        Entities::Assessment::KnowledgeGap.new(id: record.id, student_id: record.student_id, essential_id: record.essential_id,
                                               status: record.status, failed_sessions_count: record.failed_sessions_count)
      end
    end
  end
end

# 🔌 INFRA · Repositories::Crm::GenerationRepository
# Rôle : écrit et relit les générations des modèles de langage (table crm_generations) ; une seule en cours par école et par type
# ADR  : XXXX (modèles de langage, contexte crm)
module Repositories
  module Crm
    class GenerationRepository
      include Ports::Crm::GenerationRepositoryPort

      # L'index unique partiel (school_id, kind) WHERE status = 'pending' tranche la course entre deux clics simultanés.
      def create_pending(generation:)
        record = Orm::CrmGeneration.create!(school_id: generation.school_id, kind: generation.kind, status: "pending",
                                            requested_by_id: generation.requested_by_id, follow_up_id: generation.follow_up_id,
                                            input_fingerprint: generation.input_fingerprint)
        ::Shared::Result.success(to_entity(record))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict)
      end

      def find_by_public_id(public_id:)
        record = Orm::CrmGeneration.find_by(public_id:)
        to_entity(record) if record
      end

      def pending_for(school_id:, kind:)
        record = Orm::CrmGeneration.find_by(school_id:, kind:, status: "pending")
        to_entity(record) if record
      end

      def latest_done(school_id:, kind:, input_fingerprint:)
        return nil if input_fingerprint.blank?

        record = Orm::CrmGeneration.where(school_id:, kind:, status: "done", input_fingerprint:).order(created_at: :desc, id: :desc).first
        to_entity(record) if record
      end

      def complete(public_id:, content:, model:, input_tokens:, output_tokens:, duration_ms:)
        finish(public_id, status: "done", content:, model:, input_tokens:, output_tokens:, duration_ms:)
      end

      def mark_failed(public_id:, error_code:, duration_ms:)
        finish(public_id, status: "failed", error_code:, duration_ms:)
      end

      # L'audio est purgé avant la fermeture : si la purge échoue, la ligne reste en attente et sera reprise au prochain passage.
      def fail_stale(school_id:, kind:, before:)
        stale = Orm::CrmGeneration.where(status: "pending", created_at: ...before)
        stale = stale.where(school_id:) if school_id
        stale = stale.where(kind:) if kind
        stale.with_attached_audio.find_each.sum do |record|
          record.audio.purge if record.audio.attached?
          Orm::CrmGeneration.where(id: record.id, status: "pending").update_all(status: "failed", error_code: "timeout", updated_at: Time.current)
        end
      end

      private

      # Écriture conditionnelle : seule une ligne encore en attente est écrite (un second job ne peut pas écraser un résultat).
      def finish(public_id, **attributes)
        record = Orm::CrmGeneration.find_by(public_id:)
        return ::Shared::Result.failure(:not_found) if record.nil?

        written = Orm::CrmGeneration.where(public_id:, status: "pending").update_all(attributes.merge(updated_at: Time.current))
        return ::Shared::Result.failure(:conflict) if written.zero?

        ::Shared::Result.success(to_entity(record.reload))
      end

      def to_entity(record)
        Entities::Crm::Generation.new(public_id: record.public_id, school_id: record.school_id, kind: record.kind, status: record.status,
                                      requested_by_id: record.requested_by_id, follow_up_id: record.follow_up_id,
                                      input_fingerprint: record.input_fingerprint, content: record.content, error_code: record.error_code,
                                      model: record.model, input_tokens: record.input_tokens, output_tokens: record.output_tokens,
                                      duration_ms: record.duration_ms, created_at: record.created_at)
      end
    end
  end
end

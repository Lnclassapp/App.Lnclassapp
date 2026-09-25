# 🧠 DOMAINE · UseCases::Catalog::DeleteSeries
# Rôle : l'équipe supprime une série vierge ; liée à un niveau, ou portée par une classe ou un cours, elle est gardée
# ADR  : 0026, 0028, 0034, 0036
module UseCases
  module Catalog
    class DeleteSeries
      def initialize(taxonomy:, audit_log:, transaction:, policy:, clock:)
        @taxonomy = taxonomy
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result(Series supprimée) | :forbidden | :not_found | :conflict (base: referenced)
      def call(actor:, slug:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        series = @taxonomy.find_series(slug:)
        return Shared::Result.failure(:not_found) if series.nil?

        @transaction.call do
          deleted = @taxonomy.delete_series(id: series.id)
          next deleted if deleted.failure?

          record(actor, series)
          Shared::Result.success(series)
        end
      end

      private

      def record(actor, series)
        @audit_log.record(action: "taxonomy.changed", actor_id: actor.user_id, subject_type: "Series", subject_id: series.id,
                          metadata: { change: "series.deleted", slug: series.slug }, at: @clock.now)
      end
    end
  end
end

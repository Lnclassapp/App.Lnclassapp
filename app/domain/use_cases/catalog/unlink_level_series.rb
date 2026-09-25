# 🧠 DOMAINE · UseCases::Catalog::UnlinkLevelSeries
# Rôle : l'équipe retire une série d'un niveau ; un couple porté par une classe ou un cours est refusé, jamais en silence
# ADR  : 0026, 0028, 0034, 0036
module UseCases
  module Catalog
    class UnlinkLevelSeries
      def initialize(taxonomy:, audit_log:, transaction:, policy:, clock:)
        @taxonomy = taxonomy
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result | :forbidden | :not_found | :conflict (base: referenced)
      def call(actor:, level_slug:, series_slug:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        level = @taxonomy.find_level(slug: level_slug)
        series = @taxonomy.find_series(slug: series_slug)
        return Shared::Result.failure(:not_found) if level.nil? || series.nil?

        @transaction.call do
          unlinked = @taxonomy.unlink(level_id: level.id, series_id: series.id)
          record(actor, level, series) if unlinked.success?
          unlinked
        end
      end

      private

      def record(actor, level, series)
        @audit_log.record(action: "taxonomy.changed", actor_id: actor.user_id, subject_type: "Series", subject_id: series.id,
                          metadata: { change: "level_series.unlinked", level: level.slug, series: series.slug }, at: @clock.now)
      end
    end
  end
end

# 🧠 DOMAINE · UseCases::Catalog::LinkLevelSeries
# Rôle : l'équipe ouvre une série à un niveau ; seul un couple lié est accepté sur une classe ou un cours
# ADR  : 0026, 0028, 0034
module UseCases
  module Catalog
    class LinkLevelSeries
      def initialize(taxonomy:, audit_log:, transaction:, policy:, clock:)
        @taxonomy = taxonomy
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result | :forbidden | :not_found | :conflict (base: already_linked)
      def call(actor:, level_slug:, series_slug:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        level = @taxonomy.find_level(slug: level_slug)
        series = @taxonomy.find_series(slug: series_slug)
        return Shared::Result.failure(:not_found) if level.nil? || series.nil?

        now = @clock.now
        @transaction.call do
          linked = @taxonomy.link(level_id: level.id, series_id: series.id, at: now)
          record(actor, level, series, now) if linked.success?
          linked
        end
      end

      private

      def record(actor, level, series, now)
        @audit_log.record(action: "taxonomy.changed", actor_id: actor.user_id, subject_type: "Series", subject_id: series.id,
                          metadata: { change: "level_series.linked", level: level.slug, series: series.slug }, at: now)
      end
    end
  end
end

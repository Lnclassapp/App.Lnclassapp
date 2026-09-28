# 🧠 DOMAINE · UseCases::Catalog::LinkLevelSeries
# Rôle : l'équipe ouvre une série à un niveau du second cycle, et le couple reçoit ses nombres par défaut au barème
# ADR  : 0026, 0028, 0034, 0058
module UseCases
  module Catalog
    class LinkLevelSeries
      # classroom_plan : le barème ; un couple nouveau y reçoit ses nombres par défaut, jamais écrasés (ADR-0058, D1).
      def initialize(taxonomy:, classroom_plan:, audit_log:, transaction:, policy:, clock:)
        @taxonomy = taxonomy
        @classroom_plan = classroom_plan
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result | :forbidden | :not_found | :invalid (base: first_cycle) | :conflict (base: already_linked)
      def call(actor:, level_slug:, series_slug:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        level = @taxonomy.find_level(slug: level_slug)
        series = @taxonomy.find_series(slug: series_slug)
        return Shared::Result.failure(:not_found) if level.nil? || series.nil?
        # Les séries n'existent qu'au second cycle, comme dans DefaultClassroomPlan.
        return Shared::Result.failure(:invalid, errors: { base: [ :first_cycle ] }) if level.first_cycle?

        now = @clock.now
        @transaction.call do
          linked = @taxonomy.link(level_id: level.id, series_id: series.id, at: now)
          if linked.success?
            record(actor, level, series, now)
            Entities::Classroom::ClassroomPlanDefaults.fill(classroom_plan: @classroom_plan, audit_log: @audit_log, actor:,
                                                            level:, series:, at: now)
          end
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

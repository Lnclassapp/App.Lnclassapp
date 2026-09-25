# 🧠 DOMAINE · UseCases::Catalog::UpdateSeries
# Rôle : l'équipe renomme une série ; son slug reste figé, la génération des classes et les imports la reconnaissent
# ADR  : 0026, 0028, 0029, 0034
module UseCases
  module Catalog
    class UpdateSeries
      def initialize(taxonomy:, audit_log:, transaction:, policy:, clock:)
        @taxonomy = taxonomy
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Catalog::SeriesInput. → Result(Series) | :forbidden | :not_found | :invalid | :conflict (name taken)
      def call(actor:, slug:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        current = @taxonomy.find_series(slug:)
        return Shared::Result.failure(:not_found) if current.nil?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        @transaction.call do
          updated = @taxonomy.update_series(series: Entities::Catalog::Series.new(id: current.id, slug: current.slug, name: dto.name))
          record(actor, current) if updated.success?
          updated
        end
      end

      private

      def record(actor, series)
        @audit_log.record(action: "taxonomy.changed", actor_id: actor.user_id, subject_type: "Series", subject_id: series.id,
                          metadata: { change: "series.updated", slug: series.slug }, at: @clock.now)
      end
    end
  end
end

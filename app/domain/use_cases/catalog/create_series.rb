# 🧠 DOMAINE · UseCases::Catalog::CreateSeries
# Rôle : l'équipe crée une série ; son slug, dérivé du nom puis figé, devient son code (génération, imports)
# ADR  : 0026, 0028, 0029, 0034
module UseCases
  module Catalog
    class CreateSeries
      def initialize(taxonomy:, audit_log:, transaction:, policy:, clock:)
        @taxonomy = taxonomy
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Catalog::SeriesInput. → Result(Series) | :forbidden | :invalid | :conflict (name taken)
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        @transaction.call do
          created = @taxonomy.create_series(series: Entities::Catalog::Series.new(name: dto.name))
          record(actor, created.value) if created.success?
          created
        end
      end

      private

      def record(actor, series)
        @audit_log.record(action: "taxonomy.changed", actor_id: actor.user_id, subject_type: "Series", subject_id: series.id,
                          metadata: { change: "series.created", slug: series.slug }, at: @clock.now)
      end
    end
  end
end

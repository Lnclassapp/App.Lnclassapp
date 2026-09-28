# 🧠 DOMAINE · UseCases::Catalog::CreateLevel
# Rôle : l'équipe crée un niveau ; son slug, dérivé du nom puis figé, est le code de la génération des classes
# ADR  : 0026, 0028, 0029, 0034, 0058
module UseCases
  module Catalog
    class CreateLevel
      # classroom_plan : le barème ; un niveau du premier cycle au code connu y reçoit ses nombres par défaut (ADR-0058, D1).
      def initialize(taxonomy:, classroom_plan:, audit_log:, transaction:, policy:, clock:)
        @taxonomy = taxonomy
        @classroom_plan = classroom_plan
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Catalog::LevelInput. → Result(Level) | :forbidden | :invalid | :conflict (nom ou position pris)
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        level = Entities::Catalog::Level.new(**dto.level_attributes)
        return Shared::Result.failure(:invalid, errors: level.errors.to_hash) unless level.valid?

        @transaction.call { create(actor, level) }
      end

      private

      def create(actor, level)
        created = @taxonomy.create_level(level:)
        if created.success?
          @audit_log.record(action: "taxonomy.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "Level",
                            subject_id: created.value.id, metadata: { operation: "create", slug: created.value.slug })
          fill_plan(actor, created.value) if created.value.first_cycle?
        end
        created
      end

      def fill_plan(actor, level)
        Entities::Classroom::ClassroomPlanDefaults.fill(classroom_plan: @classroom_plan, audit_log: @audit_log, actor:, level:,
                                                        series: nil, at: @clock.now)
      end
    end
  end
end

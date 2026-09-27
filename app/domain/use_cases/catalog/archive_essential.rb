# 🧠 DOMAINE · UseCases::Catalog::ArchiveEssential
# Rôle : l'équipe archive une fiche publiée ; ses exercices, leurs sessions et les assignations restent en base
# ADR  : 0026, 0028, 0035, 0036, 0050
module UseCases
  module Catalog
    class ArchiveEssential
      def initialize(essentials:, audit_log:, transaction:, policy:, clock:)
        @essentials = essentials
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result(Essential relue) | :forbidden | :not_found | :conflict (base: transition_not_allowed)
      def call(actor:, slug:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        essential = @essentials.find_by_slug(slug:)
        return Shared::Result.failure(:not_found) if essential.nil?

        allowed_transition = Entities::Catalog::ContentStatus.transition(from: essential.status, to: "archived",
                                                                         parent_published: essential.course_published?)
        return allowed_transition if allowed_transition.failure?

        @transaction.call { archive(actor, essential) }
      end

      private

      # Seul le statut de la fiche change : aucune écriture sur ses exercices ni sur les assignations (ADR-0036).
      def archive(actor, essential)
        at = @clock.now
        @essentials.transition(id: essential.id, to: "archived", at:)
        @audit_log.record(action: "content.archived", actor_id: actor.user_id, at:, subject_type: "Essential",
                          subject_id: essential.id, metadata: { slug: essential.slug })
        Shared::Result.success(@essentials.find_by_slug(slug: essential.slug))
      end
    end
  end
end

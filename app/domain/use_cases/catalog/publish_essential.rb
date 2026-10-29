# 🧠 DOMAINE · UseCases::Catalog::PublishEssential
# Rôle : l'équipe publie une fiche brouillon ou archivée, seulement si son cours est publié ; inscrit au journal
# ADR  : 0026, 0028, 0035, 0050, 0116
module UseCases
  module Catalog
    class PublishEssential
      def initialize(essentials:, audit_log:, transaction:, policy:, clock:)
        @essentials = essentials
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result(Essential relue) | :forbidden | :not_found
      #   | :conflict (base: parent_not_published | transition_not_allowed)
      def call(actor:, slug:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        essential = @essentials.find_by_slug(slug:)
        return Shared::Result.failure(:not_found) if essential.nil?

        allowed_transition = Entities::Shared::ContentStatus.transition(from: essential.status, to: "published",
                                                                         parent_published: essential.course_published?)
        return allowed_transition if allowed_transition.failure?

        @transaction.call { publish(actor, essential) }
      end

      private

      # Verrou puis écriture : une modification qui suit attend ce verrou et voit la fiche publiée (menace.md, n° 15).
      def publish(actor, essential)
        @essentials.lock(id: essential.id)

        at = @clock.now
        @essentials.transition(id: essential.id, to: "published", at:)
        @audit_log.record(action: "content.published", actor_id: actor.user_id, at:, subject_type: "Essential",
                          subject_id: essential.id, metadata: { slug: essential.slug })
        Shared::Result.success(@essentials.find_by_slug(slug: essential.slug))
      end
    end
  end
end

# 🧠 DOMAINE · UseCases::Catalog::PublishEssential
# Rôle : l'équipe publie une fiche brouillon ou archivée, seulement si son cours est publié et ses images complètes ; inscrit au journal
# ADR  : 0026, 0028, 0035, 0050, 0105
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

      # ADR-0105 §4.4 : ce qui manque à une fiche pour être publiée → Result(nil) | :conflict, rien n'est écrit :
      # base: image_slots_unreadable (texte trop complexe à relire), image_slots_malformed puis image_slots_left (count :
      # emplacements mal écrits ou restants), puis base: image_alts_blank (image_alts: public_id sans alt).
      def self.images_ready(essential)
        errors = essential.image_publish_errors
        return Shared::Result.failure(:conflict, errors: { base: [ :image_slots_unreadable ] }) if errors.key?(:image_slots_unreadable)

        %i[image_slots_malformed image_slots_left].each do |reason|
          return Shared::Result.failure(:conflict, errors: { base: [ reason ], count: errors[reason] }) if errors.key?(reason)
        end
        if errors.key?(:image_alts_blank)
          return Shared::Result.failure(:conflict, errors: { base: [ :image_alts_blank ], image_alts: errors[:image_alts_blank] })
        end

        Shared::Result.success(nil)
      end

      # → Result(Essential relue) | :forbidden | :not_found
      #   | :conflict (base: parent_not_published | transition_not_allowed | image_slots_unreadable | image_slots_malformed | image_slots_left | image_alts_blank)
      def call(actor:, slug:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        essential = @essentials.find_by_slug(slug:)
        return Shared::Result.failure(:not_found) if essential.nil?

        allowed_transition = Entities::Shared::ContentStatus.transition(from: essential.status, to: "published",
                                                                         parent_published: essential.course_published?)
        return allowed_transition if allowed_transition.failure?

        ready = PublishEssential.images_ready(essential)
        return ready if ready.failure?

        @transaction.call { publish(actor, essential) }
      end

      private

      def publish(actor, essential)
        at = @clock.now
        @essentials.transition(id: essential.id, to: "published", at:)
        @audit_log.record(action: "content.published", actor_id: actor.user_id, at:, subject_type: "Essential",
                          subject_id: essential.id, metadata: { slug: essential.slug })
        Shared::Result.success(@essentials.find_by_slug(slug: essential.slug))
      end
    end
  end
end

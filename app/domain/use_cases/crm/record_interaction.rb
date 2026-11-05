# 🧠 DOMAINE · UseCases::Crm::RecordInteraction
# Rôle : note un échange avec une école (journal en ajout seul) et, si demandé, crée la relance proposée dans la même transaction
# ADR  : XXXX (contexte crm), 0028 · UDR : XXXX (bloc « Suivi » de la fiche établissement)
module UseCases
  module Crm
    class RecordInteraction
      # Tolérance d'horloge entre un téléphone et le serveur : un échange noté « maintenant » n'est jamais refusé.
      FUTURE_TOLERANCE = 5 * 60 # secondes

      def initialize(interactions:, follow_ups:, policy:, transaction:, clock:)
        @interactions = interactions
        @follow_ups = follow_ups
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # contact_public_id : le contact choisi, résolu par le dépôt (inconnu → :not_found, rien n'est écrit).
      # follow_up : nil, ou { due_on:, assignee_id:, reason: } (la relance proposée).
      # → Result(Interaction) | :forbidden | :invalid (errors par champ) | :not_found (contact inconnu) | :conflict (écriture refusée, rien n'est gardé)
      def call(actor:, school_id:, kind:, outcome:, occurred_at: nil, contact_public_id: nil, contact_name: nil, next_step: nil, note: nil,
               source: "manual", follow_up: nil)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        now = @clock.now
        interaction = build(actor, school_id, { kind:, outcome:, source:, occurred_at: occurred_at || now, contact_id: nil,
                                                contact_name: clean(contact_name), next_step: clean(next_step), note: clean(note) })
        errors = interaction_errors(interaction, now).merge(follow_up_errors(follow_up, now))
        return Shared::Result.failure(:invalid, errors:) if errors.any?

        persist(interaction, contact_public_id, follow_up, actor)
      end

      private

      def build(actor, school_id, values)
        Entities::Crm::Interaction.new(public_id: nil, school_id:, author_id: actor.user_id, **values)
      end

      def clean(text) = text.to_s.strip.presence

      def interaction_errors(interaction, now)
        entity = Entities::Crm::Interaction
        invalid = []
        invalid << :kind unless entity::KINDS.include?(interaction.kind)
        invalid << :outcome unless entity::OUTCOMES.include?(interaction.outcome)
        invalid << :source unless entity::SOURCES.include?(interaction.source)
        invalid << :next_step if interaction.next_step && interaction.next_step.length > entity::NEXT_STEP_MAX
        invalid << :note if interaction.note && interaction.note.length > entity::NOTE_MAX
        invalid << :contact_name if interaction.contact_name && interaction.contact_name.length > Entities::Crm::Contact::NAME_MAX
        invalid << :occurred_at if interaction.occurred_at > now + FUTURE_TOLERANCE
        invalid.to_h { [ it, [ :invalid ] ] }
      end

      def follow_up_errors(follow_up, now)
        return {} if follow_up.nil?

        due_on = follow_up[:due_on]
        reason = follow_up[:reason].to_s.strip
        errors = {}
        errors[:follow_up_due_on] = [ :invalid ] unless due_on.is_a?(Date) && due_on >= now.to_date
        errors[:follow_up_reason] = [ :invalid ] if reason.empty? || reason.length > Entities::Crm::FollowUp::REASON_MAX
        errors
      end

      # Une écriture refusée par la base annule les deux : pas d'échange sans la relance promise, ni l'inverse.
      def persist(interaction, contact_public_id, follow_up, actor)
        written = @transaction.attempt do
          saved = @interactions.create(interaction:, contact_public_id:)
          schedule(saved.value, follow_up, actor) if saved.success? && follow_up
          saved
        end
        written.success? ? written.value : written
      end

      def schedule(interaction, follow_up, actor)
        @follow_ups.create(follow_up: Entities::Crm::FollowUp.new(
          public_id: nil, school_id: interaction.school_id, assignee_id: follow_up[:assignee_id], due_on: follow_up[:due_on],
          reason: follow_up[:reason].to_s.strip, status: "open", done_at: nil, done_by_id: nil, created_by_id: actor.user_id,
          interaction_id: nil # le dépôt le résout depuis interaction_public_id (l'entité n'expose pas l'identifiant interne)
        ), interaction_public_id: interaction.public_id)
      end
    end
  end
end

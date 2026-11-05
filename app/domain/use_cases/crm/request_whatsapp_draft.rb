# 🧠 DOMAINE · UseCases::Crm::RequestWhatsappDraft
# Rôle : « Rédiger un message » sur une relance : réaffiche le dernier brouillon si les entrées sont inchangées (empreinte), sinon crée la génération et met le job en file
# ADR  : XXXX (modèles de langage : empreinte des entrées, réutilisation, une génération en cours par école) · UDR : XXXX (assistants du suivi)
module UseCases
  module Crm
    class RequestWhatsappDraft
      KIND = "whatsapp_draft".freeze
      # reused : le brouillon réaffiché n'a coûté aucun appel au modèle.
      Requested = Data.define(:generation, :reused)

      # inputs : #call(public_id:) → Entities::Crm::WhatsappDraftPrompt | nil (relance inconnue ou déjà faite) ; enqueue : #call(public_id) → false si la file refuse.
      def initialize(generations:, inputs:, policy:, enqueue:)
        @generations = generations
        @inputs = inputs
        @policy = policy
        @enqueue = enqueue
      end

      # → success(Requested) | :forbidden | :not_found | :conflict (un brouillon est déjà en cours pour une autre relance de l'école)
      def call(actor:, follow_up_public_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        prompt = @inputs.call(public_id: follow_up_public_id)
        return Shared::Result.failure(:not_found) if prompt.nil?

        fingerprint = prompt.fingerprint
        done = @generations.latest_done(school_id: prompt.school_id, kind: KIND, input_fingerprint: fingerprint)
        return Shared::Result.success(Requested.new(generation: done, reused: true)) if done

        start(actor, prompt, fingerprint)
      end

      private

      def start(actor, prompt, fingerprint)
        created = @generations.create_pending(generation: Entities::Crm::Generation.new(
          public_id: nil, school_id: prompt.school_id, kind: KIND, status: "pending", requested_by_id: actor.user_id, follow_up_id: prompt.follow_up_id,
          input_fingerprint: fingerprint, content: nil, error_code: nil, model: nil, input_tokens: nil, output_tokens: nil, duration_ms: nil
        ))
        return running(prompt) if created.failure?

        generation = created.value
        return Shared::Result.success(Requested.new(generation:, reused: false)) if @enqueue.call(generation.public_id) != false

        failed = @generations.mark_failed(public_id: generation.public_id, error_code: "provider_error", duration_ms: 0)
        Shared::Result.success(Requested.new(generation: failed.success? ? failed.value : generation, reused: false))
      end

      # Un autre clic est déjà en cours : on montre cette attente s'il porte sur la même relance, sinon on refuse (une seule génération par école et type).
      def running(prompt)
        pending = @generations.pending_for(school_id: prompt.school_id, kind: KIND)
        return Shared::Result.failure(:conflict) if pending.nil? || pending.follow_up_id != prompt.follow_up_id

        Shared::Result.success(Requested.new(generation: pending, reused: false))
      end
    end
  end
end

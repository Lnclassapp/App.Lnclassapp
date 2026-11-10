# 🧠 DOMAINE · UseCases::Crm::RequestBriefing
# Rôle : « Préparer l'appel » : réaffiche la dernière fiche si les entrées sont inchangées (empreinte), sinon crée la génération et met le job en file
# ADR  : XXXX (modèles de langage : empreinte des entrées, réutilisation, une génération en cours par école) · UDR : XXXX (assistants du suivi)
module UseCases
  module Crm
    class RequestBriefing
      # Au-delà (5 s + 30 s de délais du fournisseur, plus la file), une génération « en attente » est orpheline : elle est fermée avant toute nouvelle demande.
      STALE_AFTER = 2.minutes
      KIND = "briefing".freeze
      # reused : la fiche réaffichée n'a coûté aucun appel au modèle.
      Requested = Data.define(:generation, :reused)

      # inputs : #call(public_id:) → Entities::Crm::BriefingPrompt | nil ; enqueue : #call(public_id) → false si la file refuse.
      def initialize(generations:, inputs:, policy:, enqueue:, logger: nil)
        @generations = generations
        @inputs = inputs
        @policy = policy
        @enqueue = enqueue
        @logger = logger
      end

      # → success(Requested) | :forbidden | :not_found | :unavailable (file refusée)
      def call(actor:, school_public_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        prompt = @inputs.call(public_id: school_public_id)
        return Shared::Result.failure(:not_found) if prompt.nil?

        @generations.fail_stale(school_id: prompt.school_id, kind: KIND, before: Time.current - STALE_AFTER)
        fingerprint = prompt.fingerprint
        done = @generations.latest_done(school_id: prompt.school_id, kind: KIND, input_fingerprint: fingerprint)
        return Shared::Result.success(Requested.new(generation: done, reused: true)) if done

        start(actor, prompt, fingerprint)
      end

      private

      def start(actor, prompt, fingerprint)
        created = @generations.create_pending(generation: Entities::Crm::Generation.new(
          public_id: nil, school_id: prompt.school_id, kind: KIND, status: "pending", requested_by_id: actor.user_id, follow_up_id: nil,
          input_fingerprint: fingerprint, content: nil, error_code: nil, model: nil, input_tokens: nil, output_tokens: nil, duration_ms: nil
        ))
        # Un autre clic est déjà en cours : on montre cette attente, sans seconde génération.
        return running(prompt) if created.failure?

        generation = created.value
        return Shared::Result.success(Requested.new(generation:, reused: false)) if @enqueue.call(generation.public_id) != false

        failed = @generations.mark_failed(public_id: generation.public_id, error_code: "provider_error", duration_ms: 0)
        return unavailable(generation) if failed.failure?

        Shared::Result.success(Requested.new(generation: failed.value, reused: false))
      end

      # La file a refusé et la ligne n'a pas pu être fermée : elle reste « en attente » jusqu'à sa péremption (STALE_AFTER) ; ce n'est pas un succès.
      def unavailable(generation)
        @logger&.error("[crm.generation] #{KIND} #{generation.public_id} : file refusée, mark_failed impossible (error_code=provider_error)")
        Shared::Result.failure(:unavailable, errors: { reason: :provider_error })
      end

      def running(prompt)
        pending = @generations.pending_for(school_id: prompt.school_id, kind: KIND)
        return Shared::Result.failure(:conflict) if pending.nil?

        Shared::Result.success(Requested.new(generation: pending, reused: false))
      end
    end
  end
end

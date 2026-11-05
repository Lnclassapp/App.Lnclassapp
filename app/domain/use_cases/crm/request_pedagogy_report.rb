# 🧠 DOMAINE · UseCases::Crm::RequestPedagogyReport
# Rôle : « Rapport pédagogique » : sans activité, rien (aucun appel au modèle, CA-30) ; synthèse déjà faite pour les mêmes chiffres, réaffichée ; sinon génération créée et job en file
# ADR  : XXXX (modèles de langage : empreinte des entrées, réutilisation, une génération en cours par école) · UDR : XXXX (assistants du suivi)
module UseCases
  module Crm
    class RequestPedagogyReport
      KIND = "pedagogy_report".freeze
      # generation nil : l'école n'a pas assez d'activité, rien n'a été demandé au modèle. reused : la synthèse réaffichée n'a coûté aucun appel.
      Requested = Data.define(:generation, :reused) do
        def no_activity? = generation.nil?
      end

      # inputs : #call(public_id:) → Entities::Crm::PedagogyReportPrompt | nil ; enqueue : #call(public_id) → false si la file refuse.
      def initialize(generations:, inputs:, policy:, enqueue:)
        @generations = generations
        @inputs = inputs
        @policy = policy
        @enqueue = enqueue
      end

      # → success(Requested) | :forbidden | :not_found | :conflict
      def call(actor:, school_public_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        prompt = @inputs.call(public_id: school_public_id)
        return Shared::Result.failure(:not_found) if prompt.nil?
        return Shared::Result.success(Requested.new(generation: nil, reused: false)) unless prompt.activity?

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
        return running(prompt) if created.failure?

        generation = created.value
        return Shared::Result.success(Requested.new(generation:, reused: false)) if @enqueue.call(generation.public_id) != false

        failed = @generations.mark_failed(public_id: generation.public_id, error_code: "provider_error", duration_ms: 0)
        Shared::Result.success(Requested.new(generation: failed.success? ? failed.value : generation, reused: false))
      end

      def running(prompt)
        pending = @generations.pending_for(school_id: prompt.school_id, kind: KIND)
        return Shared::Result.failure(:conflict) if pending.nil?

        Shared::Result.success(Requested.new(generation: pending, reused: false))
      end
    end
  end
end

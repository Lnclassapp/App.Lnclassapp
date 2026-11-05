# 🌐 DELIVERY · Teams::Crm::BriefingsController
# Rôle : « Préparer l'appel » : demande la fiche (ou réaffiche la dernière si rien n'a changé) et rend le frame school_crm_briefing ; garde ManageCrmPolicy héritée
# ADR  : XXXX (modèles de langage, contexte crm) · UDR : XXXX (assistants du suivi)
module Teams
  module Crm
    class BriefingsController < BaseController
      def create
        result = request_briefing.call(actor: current_actor, school_public_id: params[:school_public_id])
        return render_not_found if result.code == :not_found
        return render_refused(result) if result.failure?

        @school_public_id = params[:school_public_id]
        # Relue après la demande : un travail déjà exécuté (file en ligne) est montré fini, pas en attente.
        @generation = generations.find_by_public_id(public_id: result.value.generation.public_id)
        respond_to { |format| format.turbo_stream }
      end

      private

      # 409 est réservé au code :conflict (une préparation est déjà en cours) ; tout autre échec a son message et un 503.
      def render_refused(result)
        @conflict = result.code == :conflict
        render :refused, status: @conflict ? :conflict : :service_unavailable
      end

      def generations = @generations ||= Repositories::Crm::GenerationRepository.new

      def request_briefing
        UseCases::Crm::RequestBriefing.new(
          generations:, inputs: Queries::Crm::BriefingInputsQuery.new, policy: Policies::Crm::ManageCrmPolicy.new,
          logger: Rails.logger, enqueue: ->(public_id) { ::Crm::BriefingJob.perform_later(public_id) != false }
        )
      end
    end
  end
end

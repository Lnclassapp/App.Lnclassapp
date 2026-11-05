# 🌐 DELIVERY · Teams::Crm::WhatsappDraftsController
# Rôle : « Rédiger un message » sur une relance : la modale (#new), puis la demande du brouillon (#create) ou sa réaffichage s'il n'a pas changé ; l'application n'envoie rien
# ADR  : XXXX (modèles de langage, contexte crm) · UDR : XXXX (assistants du suivi) · garde ManageCrmPolicy héritée
module Teams
  module Crm
    class WhatsappDraftsController < BaseController
      before_action :load_follow_up

      def new
        @configured = Rails.configuration.x.language_models.api_key.present?
      end

      def create
        result = request_draft.call(actor: current_actor, follow_up_public_id: @follow_up.public_id)
        return render_not_found if result.code == :not_found

        # :conflict, c'est un brouillon déjà en cours pour une autre relance de la même école : la vue le dit.
        # Relue après la demande : un travail déjà exécuté (file en ligne) est montré fini, pas en attente.
        @generation = generations.find_by_public_id(public_id: result.value.generation.public_id) if result.success?
        respond_to { |format| format.turbo_stream }
      end

      private

      def load_follow_up
        @follow_up = Repositories::Crm::FollowUpRepository.new.find_by_public_id(public_id: params[:follow_up_public_id])
        render_not_found if @follow_up.nil? || !@follow_up.open?
      end

      def generations = @generations ||= Repositories::Crm::GenerationRepository.new

      def request_draft
        UseCases::Crm::RequestWhatsappDraft.new(
          generations:, inputs: Queries::Crm::WhatsappDraftInputsQuery.new, policy: Policies::Crm::ManageCrmPolicy.new,
          enqueue: ->(public_id) { ::Crm::WhatsappDraftJob.perform_later(public_id) != false }
        )
      end
    end
  end
end

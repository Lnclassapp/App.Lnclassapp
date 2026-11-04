# 🌐 DELIVERY · Teams::Crm::AssistantsController
# Rôle : rend la carte « Assistants » de la fiche établissement ; sans clé OpenRouter, la carte annonce « Assistant non configuré »
# ADR  : XXXX (modèles de langage, contexte crm) · UDR : XXXX (assistants du suivi)
module Teams
  module Crm
    class AssistantsController < BaseController
      def show
        @school = Queries::School::SchoolsQuery.new.find(public_id: params[:school_public_id])
        return render_not_found if @school.nil?

        @configured = Rails.configuration.x.language_models.api_key.present?
      end
    end
  end
end

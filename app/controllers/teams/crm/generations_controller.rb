# 🌐 DELIVERY · Teams::Crm::GenerationsController
# Rôle : l'état d'une génération, relu toutes les 2 s par le frame tant qu'elle est en cours (garde ManageCrmPolicy héritée)
# ADR  : XXXX (modèles de langage) · UDR : XXXX (assistants du suivi)
module Teams
  module Crm
    class GenerationsController < BaseController
      def show
        @generation = Repositories::Crm::GenerationRepository.new.find_by_public_id(public_id: params[:public_id])
        render_not_found if @generation.nil?
      end
    end
  end
end

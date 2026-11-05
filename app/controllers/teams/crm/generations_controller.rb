# 🌐 DELIVERY · Teams::Crm::GenerationsController
# Rôle : l'état d'une génération, relu toutes les 2 s par le frame tant qu'elle est en cours (garde ManageCrmPolicy héritée)
# ADR  : XXXX (modèles de langage) · UDR : XXXX (assistants du suivi)
module Teams
  module Crm
    class GenerationsController < BaseController
      # Une ligne par type de génération : la route POST de « Réessayer » (paramètre : l'école) et le partial de la fiche prête.
      # Un type absent n'a ni « Réessayer » ni rendu propre tant que sa route n'est pas servie : les Lots I, J et K ajoutent leur ligne.
      ASSISTANTS = {
        "briefing" => { retry: :teams_school_briefing_path, ready: "teams/crm/briefings/briefing" }
      }.freeze

      def show
        @generation = Repositories::Crm::GenerationRepository.new.find_by_public_id(public_id: params[:public_id])
        return render_not_found if @generation.nil?

        @assistant = ASSISTANTS.fetch(@generation.kind, {})
        @school_public_id = Repositories::School::SchoolRepository.new.find_by_id(id: @generation.school_id)&.public_id
        @retry_href = public_send(@assistant[:retry], @school_public_id) if @assistant[:retry] && @school_public_id
      end
    end
  end
end

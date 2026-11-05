# 🌐 DELIVERY · Teams::Crm::PedagogyReportsController
# Rôle : « Rapport pédagogique » : #create demande la synthèse puis redirige vers la page imprimable ; #show la rend (chiffres de la query, synthèse du modèle) ; garde ManageCrmPolicy héritée
# ADR  : XXXX (modèles de langage, contexte crm) · UDR : XXXX (assistants du suivi, « Rapport pédagogique »)
module Teams
  module Crm
    class PedagogyReportsController < BaseController
      def create
        result = request_report.call(actor: current_actor, school_public_id: params[:school_public_id])
        return render_not_found if result.code == :not_found
        return head(:conflict) if result.failure?

        @school_public_id = params[:school_public_id]
        # CA-30 : l'école n'a pas assez d'activité, rien n'est demandé au modèle ; le message prend la place de la fiche de briefing.
        return respond_to { |format| format.turbo_stream { render :no_activity } } if result.value.no_activity?

        # Relue après la demande : un travail déjà exécuté (file en ligne) est montré fini, pas en attente.
        @generation = generations.find_by_public_id(public_id: result.value.generation.public_id)
        @frame = request.headers["Turbo-Frame"].to_s
        # « Réessayer » dans le frame d'une génération : la nouvelle génération remplace l'ancien frame, la page ne bouge pas.
        return respond_to { |format| format.turbo_stream { render :retry } } if @frame.start_with?("generation_")

        redirect_to teams_pedagogy_report_path(@generation.public_id)
      end

      def show
        @generation = generations.find_by_public_id(public_id: params[:public_id])
        return render_not_found if @generation.nil? || @generation.kind != UseCases::Crm::RequestPedagogyReport::KIND

        @report = Queries::Crm::PedagogyReportQuery.new.call(school_id: @generation.school_id)
        @school_public_id = Repositories::School::SchoolRepository.new.find_by_id(id: @generation.school_id)&.public_id
        @school = Queries::School::SchoolsQuery.new.find(public_id: @school_public_id) if @school_public_id
        render_not_found if @report.nil? || @school.nil?
      end

      private

      def generations = @generations ||= Repositories::Crm::GenerationRepository.new

      def request_report
        UseCases::Crm::RequestPedagogyReport.new(
          generations:, inputs: Queries::Crm::PedagogyReportQuery.new, policy: Policies::Crm::ManageCrmPolicy.new,
          enqueue: ->(public_id) { ::Crm::PedagogyReportJob.perform_later(public_id) != false }
        )
      end
    end
  end
end

# 🌐 DELIVERY · Teams::Billing::CardBatchesController
# Rôle : l'équipe crée un lot de cartes pour un point relais (modale) et imprime sa planche, journalisée et jamais en cache (layout print, sans navigation)
# ADR  : cartes-activation (contexte billing, §4.1, §4.2 et §4.10), 0031 · UDR : caisse-equipe §3.3 et §3.4
module Teams
  module Billing
    class CardBatchesController < BaseController
      # ADR-0031 : la planche affiche les codes d'activation, jamais en cache (navigateur, proxy, Turbo).
      secret_response :show
      before_action :load_relay_point, only: %i[new create]

      def new
        @form = Dtos::Billing::CardBatchInput.new
      end

      def create
        @form = Dtos::Billing::CardBatchInput.new(params.expect(card_batch: [ :quantity, :unit_price_xof ]))
        render_result create_card_batch.call(actor: current_actor, relay_point_public_id: @relay_point.public_id, dto: @form), form: :new,
                                                                                                                              success: ->(batch) { printed(batch) }
      end

      # Les cartes du lot, par numéro ; un lot sans carte n'existe pas (404). Prix et validité sont figés sur chaque carte.
      # Chaque affichage est journalisé (jamais un code), ADR cartes-activation §4.10.
      def show
        result = print_card_batch.call(actor: current_actor, batch_public_id: params[:public_id])
        return render_result(result, success: nil) if result.failure?

        @cards = result.value
        render layout: "print"
      end

      private

      def load_relay_point
        @relay_point = relay_points.find(public_id: params[:relay_point_public_id])
        render_not_found if @relay_point.nil?
      end

      # Après la création, l'équipe arrive sur la planche, prête à imprimer (le formulaire quitte le frame « modal »).
      def printed(batch)
        redirect_to teams_billing_card_batch_sheet_path(batch.public_id), notice: t(".created", count: batch.quantity), status: :see_other
      end

      def cards = @cards_repository ||= Repositories::Billing::CardRepository.new
      def relay_points = @relay_points_repository ||= Repositories::Billing::RelayPointRepository.new

      def print_card_batch
        UseCases::Billing::PrintCardBatch.new(cards:, audit_log: Repositories::Identity::AuditLogRepository.new,
                                              policy: Policies::Billing::ManageBillingPolicy.new, clock: Time.zone)
      end

      def create_card_batch
        UseCases::Billing::CreateCardBatch.new(cards:, relay_points:, audit_log: Repositories::Identity::AuditLogRepository.new,
                                               transaction: Repositories::Shared::Transaction.new,
                                               policy: Policies::Billing::ManageBillingPolicy.new, clock: Time.zone)
      end
    end
  end
end

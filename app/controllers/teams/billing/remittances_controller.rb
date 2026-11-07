# 🌐 DELIVERY · Teams::Billing::RemittancesController
# Rôle : l'équipe saisit le versement d'un point relais dans la modale ; la caisse se recharge en Turbo Stream
# ADR  : cartes-activation (contexte billing, §4.1) · UDR : caisse-equipe §3.6
module Teams
  module Billing
    class RemittancesController < Teams::BaseController
      before_action :load_relay_points

      def new
        @form = Dtos::Billing::RemittanceInput.new(received_at: Time.current.change(sec: 0))
      end

      def create
        @form = form_input
        render_result record_remittance.call(actor: current_actor, dto: @form), form: :new, success: ->(_remittance) { respond_with_cashbox }
      end

      private

      def respond_with_cashbox
        @cashbox = cashbox_query.call(at: Time.current)
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to teams_billing_cashbox_path, notice: t(".recorded"), status: :see_other }
        end
      end

      def load_relay_points = @relay_points = cashbox_query.relay_points

      def form_input
        Dtos::Billing::RemittanceInput.new(params.expect(remittance: %i[relay_point_id amount_xof received_at reference reason]))
      end

      def cashbox_query = Queries::Billing::CashboxQuery.new

      def record_remittance
        UseCases::Billing::RecordRemittance.new(
          remittances: Repositories::Billing::RemittanceRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
          transaction: Repositories::Shared::Transaction.new, policy: Policies::Billing::ManageBillingPolicy.new, clock: Time.zone
        )
      end
    end
  end
end

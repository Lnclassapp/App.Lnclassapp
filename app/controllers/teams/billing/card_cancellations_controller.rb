# 🌐 DELIVERY · Teams::Billing::CardCancellationsController
# Rôle : l'équipe retrouve une carte par son numéro et l'annule avec un motif ; une carte activée ne s'annule pas
# ADR  : 0126 (contexte billing, §4.3) · UDR : 0159 §3.5
module Teams
  module Billing
    class CardCancellationsController < Teams::BaseController
      SERIAL_DIGITS = 9
      ERRORS_SCOPE = "teams.billing.card_cancellations.errors".freeze

      def show
        return if params[:serial].blank?

        load_card
        render_missing_card if @card.nil?
      end

      def create
        result = cancel_card.call(actor: current_actor, serial:, reason: params.fetch(:cancellation, {}).permit(:reason)[:reason])
        return redirect_to(teams_billing_cashbox_path, notice: t(".cancelled", serial: serial_label), status: :see_other) if result.success?

        refuse(result)
      end

      private

      # « N° 000021 », « 21 » : les chiffres seuls, bornés ; nil sans chiffre.
      def serial = params[:serial].to_s.scan(/\d/).join.first(SERIAL_DIGITS).presence&.to_i

      def serial_label = serial.to_s.rjust(6, "0")

      def load_card
        @card = serial && Repositories::Billing::CardRepository.new.find_by_serial(serial:)
        @relay_point = Queries::Billing::CashboxQuery.new.relay_points.find { it.id == @card.relay_point_id } if @card
      end

      def render_missing_card
        @error = t("#{ERRORS_SCOPE}.not_found")
        render :show, status: :not_found
      end

      def refuse(result)
        load_card
        return render_missing_card if @card.nil?

        @error = t("#{ERRORS_SCOPE}.#{result.errors.values.flatten.first}", default: t("errors.codes.#{result.code}"))
        render :show, status: :unprocessable_content
      end

      def cancel_card
        UseCases::Billing::CancelCard.new(
          cards: Repositories::Billing::CardRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
          transaction: Repositories::Shared::Transaction.new, policy: Policies::Billing::ManageBillingPolicy.new, clock: Time.zone
        )
      end
    end
  end
end

# 🌐 DELIVERY · Teams::PushPlansController
# Rôle : le plan du jour de l'équipe, lu dans le frame « push_plan » de la page Notifications ; l'erreur de calcul reste dans le frame
# ADR  : XXXX envois de notifications (§4.4) · UDR : XXXX écran notifications de l'équipe (§3.4, §3.7) · garde : celle de BaseController (équipe seule)
module Teams
  class PushPlansController < BaseController
    def show
      @now = Time.current
      @entries = Queries::Communication::PushDailyPlanQuery.new.call(now: @now)
      @closed = UseCases::Communication::ApprovePushMotive.closed?(@now)
    rescue StandardError => error
      Rails.error.report(error, handled: true, context: { controller: self.class.name })
      render :error, status: :service_unavailable
    end
  end
end

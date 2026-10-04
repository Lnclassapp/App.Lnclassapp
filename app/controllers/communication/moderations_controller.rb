# 🌐 DELIVERY · Communication::ModerationsController
# Rôle : « Enseignants » (direction) et « Toutes » (équipe, filtre par établissement) : les annonces en cours qu'on peut retirer
# ADR  : 0078 (§4.2) · UDR : 0054 (§3.9), 0071 (§3.7)
module Communication
  class ModerationsController < AuthenticatedController
    allow_roles :school_admin, :team

    helper_method :announcement_date

    # Le filtre par établissement est celui de l'équipe : la direction ne lit que son établissement.
    def index
      @search = current_actor.team? ? params[:q].to_s.squish : ""
      @page = Queries::Communication::ModerationQuery.new.page(actor: current_actor, q: @search, page: params[:page], now: Time.current)
    end

    private

    # Design system §12 : « 5 oct. », « 1ᵉʳ nov. », « 5 oct. à 10:00 » — les dates de « Mes annonces ».
    def announcement_date(value, time: false)
      day = l(value.to_date, format: t("communication.moderations.formats.#{value.day == 1 ? 'first_day' : 'day'}"))
      return day unless time

      t("communication.moderations.formats.day_and_time", day:, time: l(value, format: t("communication.moderations.formats.time")))
    end
  end
end

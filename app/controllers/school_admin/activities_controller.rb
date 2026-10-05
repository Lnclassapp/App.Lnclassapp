# 🌐 DELIVERY · SchoolAdmin::ActivitiesController
# Rôle : « Activité récente » de l'accueil de la direction (AD-17 à AD-19) : le seul contenu du frame différé, sans layout
# ADR  : 0065 · UDR : 0074 §3.11 · l'établissement est celui du compte, jamais un paramètre ; 403 par BaseController
module SchoolAdmin
  class ActivitiesController < BaseController
    # Demandée par le frame paresseux de l'accueil, elle ne rend que ce frame, en HTML seulement : un autre format reçoit 406
    # sans lire la base, comme les pages voisines (constat du challenger, D1).
    def show
      respond_to { |format| format.html { render_activity } }
    end

    private

    # Une panne de la base n'emporte pas l'accueil : le frame montre l'état d'erreur commun, et la panne est journalisée
    # (config/initializers/error_reporting.rb). Toute autre erreur est un bogue : elle remonte.
    def render_activity
      events = Queries::School::SchoolActivityQuery.new.call(school_id: current_actor.school_id, now: Time.current)
      render partial: "activity", locals: { events: }
    rescue ActiveRecord::ActiveRecordError => error
      Rails.error.report(error, handled: true)
      render partial: "activity", locals: { events: [], failed: true }, status: :service_unavailable
    end
  end
end

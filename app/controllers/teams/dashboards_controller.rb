# 🌐 DELIVERY · Teams::DashboardsController
# Rôle : pilotage de l'équipe (TR-10, TR-12) : indicateurs par période et DRENA, établissements de la DRENA ; recherche de compte (TR-11)
# ADR  : 0028, 0038, 0049, 0062 · UDR : 0006, 0049, 0068
module Teams
  class DashboardsController < BaseController
    SEARCH_FRAME = "team_dashboard_search".freeze

    # Lire les indicateurs, puis chercher un compte (recherche sans cible : ReadUserPolicy, l'équipe seule).
    def show
      render_result Policies::School::ReadIndicatorsPolicy.new.call(actor: current_actor), success: lambda { |_|
        render_result Policies::Identity::ReadUserPolicy.new.call(actor: current_actor), success: ->(_) { respond_with_search }
      }
    end

    private

    # Le frame de recherche ne reçoit que ses résultats : chercher ne recalcule pas les indicateurs.
    def respond_with_search
      @search = Queries::Identity::AccountSearchQuery.new.call(term: text_param(:q), page: text_param(:page))
      return render(partial: "search_results", locals: { search: @search }) if turbo_frame_request_id == SEARCH_FRAME

      @period = Entities::School::ReportingPeriod.parse(text_param(:period), today: Date.current)
      @dashboard = Queries::School::TeamDashboardQuery.new.call(period: @period, drena_public_id: text_param(:drena))
      @drenas = Queries::School::SchoolOptionsQuery.new.drenas
      read_schools if @dashboard.drena
    end

    # UDR-0068 §3.6 : sous filtre DRENA, « Par établissement » remplace « Par DRENA », paginé et cherché côté serveur. Ses
    # lignes viennent de la lecture des chiffres (ADR-0062, amendement du 2026-10-04) : la somme égale toujours le haut.
    def read_schools
      @school_search = text_param(:school_q)
      @schools = Queries::School::DrenaSchoolsQuery.new.page(drena: @dashboard.drena, rows: @dashboard.school_rows,
                                                             search: @school_search, page: text_param(:school_page))
    end

    # Un paramètre de la page n'est lu que s'il est un texte sans octet nul : un tableau (q[]=), un hash (page[a]=) ou
    # un octet nul (PostgreSQL le refuse) est une valeur invalide, ignorée comme un paramètre absent.
    def text_param(key)
      value = params[key]
      value if value.is_a?(String) && !value.include?("\0")
    end
  end
end

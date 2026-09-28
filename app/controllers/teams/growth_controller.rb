# 🌐 DELIVERY · Teams::GrowthController
# Rôle : page « Croissance » de l'équipe : k enseignant et sa décomposition, partages, cycle viral, parrains, classement, attente
# ADR  : 0028, 0049, 0063 · UDR : 0006, 0018, 0050 · ne touche pas /teams/dashboard (chantier pilotage-equipe)
module Teams
  class GrowthController < BaseController
    PERIODS = [ 7, 30, 90 ].freeze
    DEFAULT_PERIOD = 30

    def show
      render_result Policies::Identity::ReadGrowthPolicy.new.call(actor: current_actor), success: lambda { |_|
        @period = period
        to = Time.current
        @metrics = Queries::Identity::GrowthMetricsQuery.new.call(from: to - @period.days, to:)
      }
    end

    private

    # Lu en texte : un tableau ou un hash (period[]=7) vaut la période par défaut.
    def period
      days = params[:period].is_a?(String) ? params[:period].to_i : DEFAULT_PERIOD
      PERIODS.include?(days) ? days : DEFAULT_PERIOD
    end
  end
end

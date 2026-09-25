# 🌐 DELIVERY · Teams::LevelSeriesController
# Rôle : coche ou décoche un couple de la matrice niveau × série ; la case est remplacée, un refus répond en 422
# ADR  : 0026, 0034, 0036 · UDR : 0006, 0033
module Teams
  class LevelSeriesController < BaseController
    def create
      respond_with_cell link_level_series.call(actor: current_actor, **pair)
    end

    def destroy
      respond_with_cell unlink_level_series.call(actor: current_actor, **pair)
    end

    private

    # :conflict (couple déjà lié, ou utilisé) : la case est resynchronisée avec la base, et la raison dite.
    def respond_with_cell(result)
      return render_toggle(refused: true) if result.code == :conflict

      render_result result, success: ->(_) { render_toggle(refused: false) }
    end

    def render_toggle(refused:)
      @refused = refused
      @cell = Queries::Catalog::SeriesQuery.new.cell(**pair)
      message = t(".#{refused ? :refused : :done}", level: @cell.level_name, series: @cell.series_name)
      respond_to do |format|
        format.turbo_stream { render status: refused ? :unprocessable_entity : :ok }
        format.html { redirect_to series_index_path, flash: { (refused ? :alert : :notice) => message }, status: :see_other }
      end
    end

    def pair = { level_slug: params[:level_slug], series_slug: params[:series_slug] }

    def link_level_series = UseCases::Catalog::LinkLevelSeries.new(**dependencies)
    def unlink_level_series = UseCases::Catalog::UnlinkLevelSeries.new(**dependencies)

    def dependencies
      { taxonomy: Repositories::Catalog::TaxonomyRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, policy: Policies::Catalog::ManageTaxonomyPolicy.new, clock: Time.zone }
    end
  end
end

# 🌐 DELIVERY · Teams::SeriesController
# Rôle : séries de l'équipe : liste et matrice niveau × série, création et renommage en modale, suppression en place
# ADR  : 0026, 0034, 0036 · UDR : 0006, 0033
module Teams
  class SeriesController < BaseController
    def index
      @series = series_query.call
      @matrix = series_query.matrix
    end

    def new
      @form = Dtos::Catalog::SeriesInput.new
    end

    # Succès : toast, ligne ajoutée, matrice remplacée (nouvelle colonne) ; la modale se ferme sur l'envoi réussi.
    def create
      @form = form_input
      render_result create_series.call(actor: current_actor, dto: @form), form: :new, success: lambda { |series|
        @row = series_query.find(slug: series.slug)
        @matrix = series_query.matrix
        respond_with_list(t(".created", name: series.name))
      }
    end

    def edit
      @row = series_query.find(slug: params[:slug])
      return render_not_found if @row.nil?

      @form = Dtos::Catalog::SeriesInput.new(name: @row.name)
    end

    def update
      @row = series_query.find(slug: params[:slug])
      @form = form_input
      render_result update_series.call(actor: current_actor, slug: params[:slug], dto: @form), form: :edit, success: lambda { |series|
        @row = series_query.find(slug: series.slug)
        @matrix = series_query.matrix
        respond_with_list(t(".updated", name: series.name))
      }
    end

    # Une série liée ou utilisée est gardée : le même stream répond en 422, toast d'erreur et ligne conservée.
    def destroy
      @row = series_query.find(slug: params[:slug])
      result = delete_series.call(actor: current_actor, slug: params[:slug])
      return respond_refused if result.code == :conflict

      render_result result, success: lambda { |series|
        @matrix = series_query.matrix
        respond_with_list(t(".deleted", name: series.name))
      }
    end

    private

    def respond_with_list(notice)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to series_index_path, notice:, status: :see_other }
      end
    end

    def respond_refused
      @refused = true
      respond_to do |format|
        format.turbo_stream { render status: :unprocessable_entity }
        format.html { redirect_to series_index_path, alert: t(".referenced", name: @row.name), status: :see_other }
      end
    end

    def form_input = Dtos::Catalog::SeriesInput.new(params.expect(series: %i[name]).to_h.symbolize_keys)

    def series_query = @series_query ||= Queries::Catalog::SeriesQuery.new

    def create_series = UseCases::Catalog::CreateSeries.new(**dependencies)
    def update_series = UseCases::Catalog::UpdateSeries.new(**dependencies)
    def delete_series = UseCases::Catalog::DeleteSeries.new(**dependencies)

    def dependencies
      { taxonomy: Repositories::Catalog::TaxonomyRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, policy: Policies::Catalog::ManageTaxonomyPolicy.new, clock: Time.zone }
    end
  end
end

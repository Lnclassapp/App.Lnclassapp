# 🌐 DELIVERY · Teams::MaterialsController
# Rôle : matières du référentiel : liste, création et modification en modale, suppression refusée tant qu'elle est utilisée
# ADR  : 0026, 0034, 0036 · UDR : 0006, 0034
module Teams
  class MaterialsController < BaseController
    def index
      @materials = materials_query.call
    end

    def new
      @form = Dtos::Catalog::MaterialInput.new
    end

    def create
      @form = form_input
      render_result build(UseCases::Catalog::CreateMaterial).call(actor: current_actor, dto: @form), form: :new,
                    success: ->(_) { respond_with_list(notice: t(".done", name: @form.name)) }
    end

    def edit
      material = materials_query.find(slug: params[:slug])
      return render_not_found if material.nil?

      @form = Dtos::Catalog::MaterialInput.new(name: material.name, shortname: material.shortname, category: material.category)
    end

    def update
      @form = form_input
      result = build(UseCases::Catalog::UpdateMaterial).call(actor: current_actor, slug: params[:slug], dto: @form)
      render_result result, form: :edit, success: ->(_) { respond_with_list(notice: t(".done", name: @form.name)) }
    end

    # Refus (matière utilisée) : toast et ligne re-rendue, ce qui referme la confirmation ; rien n'est supprimé.
    def destroy
      result = build(UseCases::Catalog::DeleteMaterial).call(actor: current_actor, slug: params[:slug])
      return refuse_destroy if result.code == :conflict

      render_result result, success: ->(_) { respond_with_list(notice: t(".done")) }
    end

    private

    def respond_with_list(notice:)
      @materials = materials_query.call
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to materials_path, notice:, status: :see_other }
      end
    end

    def refuse_destroy
      @kept_material = materials_query.find(slug: params[:slug])
      respond_to do |format|
        format.turbo_stream { render :destroy, status: :unprocessable_entity }
        format.html { redirect_to materials_path, alert: t(".referenced"), status: :see_other }
      end
    end

    def form_input
      Dtos::Catalog::MaterialInput.new(**params.expect(material: %i[name shortname category]).to_h.symbolize_keys)
    end

    def materials_query = Queries::Catalog::MaterialsQuery.new

    def build(use_case)
      use_case.new(taxonomy: Repositories::Catalog::TaxonomyRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
                   policy: Policies::Catalog::ManageTaxonomyPolicy.new, transaction: Repositories::Shared::Transaction.new,
                   clock: Time.zone)
    end
  end
end

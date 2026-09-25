# 🌐 DELIVERY · Teams::DrenasController
# Rôle : l'équipe gère les DRENA : liste, création et renommage en modale, suppression refusée tant qu'il y a des écoles
# ADR  : 0026, 0028, 0029, 0036 · UDR : 0006, 0035
module Teams
  class DrenasController < BaseController
    before_action :load_drena, only: %i[edit update]

    def index
      @drenas = drenas_query.call
    end

    def new
      @form = Dtos::School::DrenaInput.new
    end

    def create
      @form = form_input
      render_result create_drena.call(actor: current_actor, dto: @form), form: :new,
                                                                            success: ->(drena) { respond_with_list(drena, :created) }
    end

    def edit
      @form = Dtos::School::DrenaInput.new(name: @drena.name)
    end

    def update
      @form = form_input
      render_result update_drena.call(actor: current_actor, public_id: @drena.public_id, dto: @form), form: :edit,
                    success: ->(drena) { respond_with_list(drena, :updated) }
    end

    # Refus (:conflict, la DRENA a des établissements) : toast d'erreur avec la raison, ligne conservée, statut 422.
    def destroy
      result = delete_drena.call(actor: current_actor, public_id: params[:public_id])
      return refuse_destroy if result.code == :conflict

      render_result result, success: lambda { |drena|
        @drena = drena
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to drenas_path, notice: t(".deleted", name: drena.name), status: :see_other }
        end
      }
    end

    private

    def load_drena
      @drena = drenas_query.find(public_id: params[:public_id])
      render_not_found if @drena.nil?
    end

    # La liste suit l'ordre des noms : une création ou un renommage la renvoie en entier.
    def respond_with_list(drena, notice)
      @drena = drena
      @drenas = drenas_query.call
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to drenas_path, notice: t(".#{notice}", name: drena.name), status: :see_other }
      end
    end

    def refuse_destroy
      @drena = drenas_query.find(public_id: params[:public_id])
      @refusal = t(".has_schools", name: @drena.name, count: @drena.schools_count)
      respond_to do |format|
        format.turbo_stream { render :destroy, status: :unprocessable_entity }
        format.html { redirect_to drenas_path, alert: @refusal, status: :see_other }
      end
    end

    def form_input = Dtos::School::DrenaInput.new(params.expect(drena: [ :name ]))

    def drenas_query = Queries::School::DrenasQuery.new

    def create_drena = UseCases::School::CreateDrena.new(**dependencies)
    def update_drena = UseCases::School::UpdateDrena.new(**dependencies)
    def delete_drena = UseCases::School::DeleteDrena.new(**dependencies)

    def dependencies
      { drenas: Repositories::School::DrenaRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, policy: Policies::School::ManageSchoolPolicy.new, clock: Time.zone }
    end
  end
end

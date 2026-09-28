# 🌐 DELIVERY · Teams::SchoolsController
# Rôle : liste nationale filtrée, fiche (et enseignants en attente), modification en modale, désactivation, suppression refusée
# ADR  : 0026, 0030, 0036, 0063 · UDR : 0006, 0036, 0050 · aucune création : un établissement n'entre que par l'import
module Teams
  class SchoolsController < BaseController
    LIST_FRAME = "schools".freeze
    FILTERS = %i[drena school_type cycle status search].freeze
    STATUS_TONES = { "active" => :success, "draft" => :warning, "inactive" => :neutral }.freeze

    helper_method :list_frame_request?, :school_status_tone, :drena_options

    def index
      @filters = params.permit(*FILTERS).to_h.symbolize_keys
      @page = schools_query.call(**@filters, page: params[:page])
    end

    # « /teams/schools/new » n'a pas de route : il arrive ici comme un public_id inconnu, donc 404.
    def show
      @school = Queries::School::SchoolDetailQuery.new.call(public_id: params[:public_id])
      return render_not_found if @school.nil?

      @join_requests = Queries::School::JoinRequestsQuery.new.for_school(school_public_id: @school.public_id)
    end

    def edit
      school = schools_query.find(public_id: params[:public_id])
      return render_not_found if school.nil?

      @form = Dtos::School::SchoolInput.new(**school.to_h.slice(:drena_public_id, :name, :sigle, :school_type, :status, :cycle,
                                                                 :national_code))
    end

    def update
      @form = form_input
      use_case = build(UseCases::School::UpdateSchool, drenas: Repositories::School::DrenaRepository.new)
      render_result use_case.call(actor: current_actor, public_id: params[:public_id], dto: @form), form: :edit,
                    success: ->(school) { respond_with_school(notice: t(".done", name: school.name)) }
    end

    def deactivate
      result = build(UseCases::School::DeactivateSchool).call(actor: current_actor, public_id: params[:public_id])
      render_result result, success: ->(school) { respond_with_school(notice: t(".done", name: school.name)) }
    end

    # Refus (établissement utilisé) : toast et ligne re-rendue, ce qui referme la confirmation ; rien n'est supprimé.
    def destroy
      result = build(UseCases::School::DeleteSchool).call(actor: current_actor, public_id: params[:public_id])
      return refuse_destroy if result.code == :conflict

      render_result result, success: ->(_) { redirect_or_stream(notice: t(".done")) }
    end

    private

    def respond_with_school(notice:)
      @school = schools_query.find(public_id: params[:public_id])
      redirect_or_stream(notice:)
    end

    def redirect_or_stream(notice:)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to schools_path, notice:, status: :see_other }
      end
    end

    def refuse_destroy
      @kept_school = schools_query.find(public_id: params[:public_id])
      respond_to do |format|
        format.turbo_stream { render :destroy, status: :unprocessable_entity }
        format.html { redirect_to schools_path, alert: t(".referenced"), status: :see_other }
      end
    end

    def form_input
      Dtos::School::SchoolInput.new(**params.expect(school: %i[drena_public_id name sigle school_type status cycle national_code]).to_h.symbolize_keys)
    end

    def list_frame_request? = turbo_frame_request_id == LIST_FRAME
    def school_status_tone(status) = STATUS_TONES.fetch(status)
    def drena_options = @drena_options ||= Queries::School::SchoolOptionsQuery.new.drenas
    def schools_query = Queries::School::SchoolsQuery.new

    def build(use_case, **dependencies)
      use_case.new(schools: Repositories::School::SchoolRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
                   policy: Policies::School::ManageSchoolPolicy.new, transaction: Repositories::Shared::Transaction.new,
                   clock: Time.zone, **dependencies)
    end
  end
end

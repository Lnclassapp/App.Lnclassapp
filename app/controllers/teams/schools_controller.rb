# 🌐 DELIVERY · Teams::SchoolsController
# Rôle : liste nationale filtrée, fiche (enseignants en attente, « Direction », « Directions retirées »), modale, confirmations lues à la demande, désactivation
# ADR  : 0026, 0030, 0036, 0059, 0063, 0076, 0077, 0088 · UDR : 0006, 0036, 0046, 0050, 0070, 0083 · aucune création : un établissement n'entre que par l'import
module Teams
  class SchoolsController < BaseController
    include SchoolStaffBlock

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
      @school = Queries::School::SchoolDetailQuery.new.call(public_id: params[:public_id], archives: params[:archives] == "1")
      return render_not_found if @school.nil?

      @level_classrooms = Queries::School::LevelClassroomsQuery.new.call(public_id: params[:public_id])
      @join_requests = Queries::School::JoinRequestsQuery.new.for_school(school_public_id: @school.public_id)
      load_school_staff(Repositories::School::SchoolRepository.new.find_by_public_id(public_id: @school.public_id))
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

    # Lot E3 (politique-cache) : la confirmation n'est plus copiée dans chaque ligne. Elle arrive dans le frame « modal » ;
    # sans frame, la même adresse est une page complète. Un établissement déjà inactif n'a rien à désactiver : 404.
    def deactivation
      @school = schools_query.find(public_id: params[:public_id])
      render_not_found if @school.nil? || @school.status == "inactive"
    end

    def deletion
      @school = schools_query.find(public_id: params[:public_id])
      render_not_found if @school.nil?
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

    # Sur la fiche, le bloc « Classes par niveau » suit le statut (« + » réservé à un établissement actif, UDR-0046).
    def respond_with_school(notice:)
      @school = schools_query.find(public_id: params[:public_id])
      @level_classrooms = Queries::School::LevelClassroomsQuery.new.call(public_id: params[:public_id])
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

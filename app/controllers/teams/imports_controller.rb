# 🌐 DELIVERY · Teams::ImportsController
# Rôle : écran des imports de l'équipe : liste, téléversement en modale, suivi rechargé tant que l'import tourne
# ADR  : 0026, 0039 · UDR : 0006
module Teams
  class ImportsController < BaseController
    STATUS_FRAME = "import_status".freeze
    STATUS_TONES = { "queued" => :neutral, "validating" => :info, "importing" => :info, "completed" => :success,
                     "rejected" => :error, "failed" => :error }.freeze

    # Le layout « shell » d'AuthenticatedController masque celui de turbo-rails : dans une réponse de frame complète,
    # le premier turbo-frame#modal serait celui, vide, du layout, et la modale resterait vide.
    layout -> { turbo_frame_request? ? "turbo_rails/frame" : "shell" }

    before_action :require_known_kind, only: %i[new create]
    helper_method :import_status_tone

    def index
      @kind = params[:kind].presence_in(Entities::Catalog::ImportKind::KINDS)
      @imports = Queries::Catalog::ImportReportsQuery.new.call(kind: @kind)
    end

    def new
      @form = Dtos::Catalog::ImportUploadInput.new(kind: params[:kind])
    end

    # Succès : toast, suivi dans la modale et ligne en tête de liste (Turbo Stream) ; repli HTML : la page de suivi.
    def create
      @form = form_input
      render_result start_import.call(actor: current_actor, dto: @form), form: :new, success: lambda { |report|
        @import = report_row(report.public_id)
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to teams_import_path(report.public_id), notice: t(".started"), status: :see_other }
        end
      }
    end

    # Le frame de suivi se recharge seul : il ne reçoit que son partial.
    def show
      @import = report_row(params[:public_id])
      return render_not_found if @import.nil?

      render_result Entities::Catalog::ImportKind.fetch(@import.kind).authorize(actor: current_actor), success: lambda { |_|
        render partial: "status", locals: { import: @import } if turbo_frame_request_id == STATUS_FRAME
      }
    end

    private

    def require_known_kind
      render_not_found unless Entities::Catalog::ImportKind.valid?(params[:kind] || params.dig(:import, :kind))
    end

    def form_input
      upload = params.dig(:import, :io)
      upload = nil unless upload.is_a?(ActionDispatch::Http::UploadedFile)
      Dtos::Catalog::ImportUploadInput.new(kind: params.dig(:import, :kind), filename: upload&.original_filename, io: upload)
    end

    def import_status_tone(status) = STATUS_TONES.fetch(status)

    def report_row(public_id) = Queries::Catalog::ImportReportQuery.new.call(public_id:)

    def start_import
      UseCases::Catalog::StartImport.new(
        reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
        queue: Repositories::Catalog::ImportQueue.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end

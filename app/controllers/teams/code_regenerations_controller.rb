# 🌐 DELIVERY · Teams::CodeRegenerationsController
# Rôle : régénération de masse des codes d'établissement ou des liens des classes : modale chiffrée, lancement, rapport
# ADR  : 0026, 0056, 0096 · UDR : 0104, 0105 · équipe admin seulement ; ni code ni jeton dans la modale ni dans le rapport
module Teams
  class CodeRegenerationsController < BaseController
    Kind = Entities::Catalog::ImportKind

    # La règle avant la cible : un membre qui n'est pas admin reçoit 403, quelle que soit l'adresse (RM-09, RM-22).
    before_action { render_forbidden unless helpers.can_regenerate_codes_in_bulk? }

    # Les filtres de la liste (ou un établissement) arrivent en paramètres ; la modale recompte toujours la sélection réelle.
    def new
      @form = Dtos::School::CodeRegenerationInput.new(target: params[:target], selection: params.permit(*SELECTION).to_h,
                                                      current_year_only: params[:all_years] != "1")
      return render_not_found unless @form.valid?

      @preview = preview
    end

    # Succès : le rapport, rechargé tant qu'il tourne. Déjà en cours : état attendu ; toast d'information et rapport de celle
    # qui tourne. Nombre faux ou sélection vide : la modale revient, recomptée (422). File indisponible : rien n'est changé,
    # le rapport est failed et l'équipe est invitée à réessayer.
    def create
      @form = form_input
      result = start.call(actor: current_actor, dto: @form)
      return redirect_to_running if result.code == :conflict
      return redirect_to_unavailable if result.code == :unavailable
      return refuse(result) if result.code == :invalid

      render_result result, success: lambda { |report|
        redirect_to teams_import_path(report.public_id), notice: t(".started.#{@form.target}"), status: :see_other
      }
    end

    private

    SELECTION = Dtos::School::SchoolSelection.members
    private_constant :SELECTION

    def form_input
      input = params.fetch(:code_regeneration, {}).permit(:target, :typed_count, :current_year_only, selection: SELECTION)
      Dtos::School::CodeRegenerationInput.new(**input.to_h.symbolize_keys)
    end

    def refuse(result)
      return render_not_found if result.errors.key?(:target)

      @preview = preview
      if result.errors.key?(:typed_count)
        @form.errors.add(:typed_count, :mismatch, number: helpers.number_with_delimiter(@preview.count))
      end
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("modal", partial: "form"), status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end

    def preview
      school_year = (Entities::Classroom::SchoolYear.current(Date.current) if @form.current_year_only)
      Queries::School::CodeRegenerationPreviewQuery.new.call(target: @form.target, selection: @form.selection, school_year:)
    end

    # Une seule régénération en cours par genre (index partiel) : aucune ne peut naître après elle, c'est la plus récente.
    def redirect_to_running
      running = Queries::Catalog::ImportReportsQuery.new.call(kind: @form.target, limit: 1).first
      redirect_to teams_import_path(running.public_id), status: :see_other, flash: {
        info: { "title" => t(".already_running_title"), "message" => t(".already_running.#{@form.target}") }
      }
    end

    def redirect_to_unavailable
      redirect_to teams_imports_path, status: :see_other, flash: { alert: t(".unavailable") }
    end

    def start
      UseCases::School::StartCodeRegeneration.new(
        reports: Repositories::Catalog::ImportReportRepository.new, queue: Repositories::Catalog::ImportQueue.new,
        schools: Repositories::School::SchoolRepository.new, classrooms: Repositories::Classroom::ClassroomRepository.new,
        policy: Policies::School::RegenerateCodesInBulkPolicy.new, clock: Time.zone
      )
    end
  end
end

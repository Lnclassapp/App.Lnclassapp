# 🌐 DELIVERY · Teams::ClassroomPlansController
# Rôle : barème des classes générées : lignes du référentiel et totaux ; modification d'une ligne en modale, en Turbo Stream
# ADR  : 0026, 0028, 0058 · UDR : 0006, 0042, 0045
module Teams
  class ClassroomPlansController < BaseController
    helper_method :line_dom_id

    def show
      render_result show_plan, success: ->(sheet) { @sheet = sheet }
    end

    def edit
      render_result show_plan, success: lambda { |sheet|
        @line = line_in(sheet)
        return render_not_found if @line.nil?

        @form = Dtos::Classroom::ClassroomPlanLineInput.from_counts(@line.counts)
      }
    end

    # La modale en 422 garde le titre de la ligne : il vient de la feuille, relue.
    def update
      @form = Dtos::Classroom::ClassroomPlanLineInput.new(params.expect(classroom_plan_line: %i[public_count private_count]))
      result = update_line.call(actor: current_actor, level_slug: params[:level_slug], series_slug: params[:series_slug], dto: @form)
      @line = line_in(show_plan.value) if result.code == :invalid
      render_result result, form: :edit, success: ->(line) { respond_updated(line) }
    end

    private

    # Identifiant de la ligne d'un niveau ou d'un couple niveau × série : cible des Turbo Streams.
    def line_dom_id(line) = "classroom_plan_line_#{line.key}"

    # → Line modifiable, ou nil : ligne inconnue, ou niveau du second cycle sans série.
    def line_in(sheet)
      sheet.lines.find { it.level_slug == params[:level_slug] && it.series_slug == params[:series_slug] && !it.unlinked? }
    end

    # La ligne et les totaux relus après l'écriture.
    def respond_updated(line)
      @sheet = show_plan.value
      @line = line_in(@sheet)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to classroom_plan_path, notice: t(".updated", name: line.name), status: :see_other }
      end
    end

    def show_plan
      UseCases::Classroom::ShowClassroomPlan.new(classroom_plan:, taxonomy:, policy:).call(actor: current_actor)
    end

    def update_line
      UseCases::Classroom::UpdateClassroomPlanLine.new(
        classroom_plan:, taxonomy:, policy:, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end

    def classroom_plan = Repositories::Classroom::ClassroomPlanRepository.new
    def taxonomy = Repositories::Catalog::TaxonomyRepository.new
    def policy = Policies::Classroom::ManageClassroomPlanPolicy.new
  end
end

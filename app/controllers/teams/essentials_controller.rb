# 🌐 DELIVERY · Teams::EssentialsController
# Rôle : notions d'une leçon : publication (seule ou avec ses exercices), archivage et correction du texte en modale ; ni création ni changement de structure à l'écran (CA-29)
# ADR  : 0026, 0028, 0035, 0113 (§4.6, amendement du 2026-11-14) · UDR : 0006, 0007, 0042 (amendement du 2026-11-14), 0129
module Teams
  class EssentialsController < BaseController
    include PublishCascade

    def publish = transition(publish_essential)
    def archive = transition(archive_essential)

    # edition-texte-lecon : le texte enregistré de la notion, dans la modale. La policy répond avant toute lecture.
    def edit_text
      allowed = policy.call(actor: current_actor)
      return render_result(allowed, success: nil) if allowed.failure?

      @essential = essential_repository.find_by_slug(slug: params[:slug])
      return render_not_found if @essential.nil?

      @text = text_from_sheet(@essential.name, essential_repository.sheet_of(id: @essential.id))
      @errors = {}
    end

    # Succès : toast, modale refermée, page de la leçon re-demandée (morphing). Refus de saisie : 422, la modale garde la saisie.
    def update_text
      @text = text_from_params
      result = correct_notion_text.call(actor: current_actor, slug: params[:slug], text: @text)
      return refuse_text(result) if result.code == :invalid

      render_result result, success: lambda { |essential|
        @essential = essential
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_back_or_to courses_path, notice: t(".updated", name: essential.name), status: :see_other }
        end
      }
    end

    private

    def refuse_text(result)
      @essential = essential_repository.find_by_slug(slug: params[:slug])
      @errors = result.errors
      render :edit_text, status: :unprocessable_entity
    end

    def text_from_sheet(name, sheet)
      UseCases::Catalog::CorrectNotionText::NotionText.new(
        name:, remember: sheet["remember"].to_s, method_steps: Array(sheet["method"]).map(&:to_s),
        example_statement: sheet.dig("example", "statement").to_s, example_steps: Array(sheet.dig("example", "steps")).map(&:to_s),
        pitfall: sheet["pitfall"].to_s
      )
    end

    def text_from_params
      input = params.expect(notion_text: [ :name, :remember, :example_statement, :pitfall, { method_steps: [], example_steps: [] } ])
      UseCases::Catalog::CorrectNotionText::NotionText.new(
        name: input[:name].to_s, remember: input[:remember].to_s, method_steps: Array(input[:method_steps]).map(&:to_s),
        example_statement: input[:example_statement].to_s, example_steps: Array(input[:example_steps]).map(&:to_s),
        pitfall: input[:pitfall].to_s
      )
    end

    def correct_notion_text = UseCases::Catalog::CorrectNotionText.new(**transition_dependencies)

    def cascade_root = :essential

    # Refus (cours non publié, transition interdite) : 422 et toast d'erreur, le panneau de statut reste tel quel. Sans Turbo,
    # retour à la page d'où le bouton a été cliqué.
    def transition(use_case)
      result = use_case.call(actor: current_actor, slug: params[:slug])
      @reason = result.errors.fetch(:base).first if result.code == :conflict
      return respond_transition(:unprocessable_entity, alert: t("teams.essentials.transition.#{@reason}")) if @reason

      render_result result, success: lambda { |essential|
        @essential = essential
        respond_transition(:ok, notice: t("teams.essentials.transition.#{essential.status}", name: essential.name))
      }
    end

    def respond_transition(status, **flash)
      respond_to do |format|
        format.turbo_stream { render :transition, status: }
        format.html { redirect_back_or_to courses_path, **flash, status: :see_other }
      end
    end

    def essential_repository = Repositories::Catalog::EssentialRepository.new

    def publish_essential = UseCases::Catalog::PublishEssential.new(**transition_dependencies)
    def archive_essential = UseCases::Catalog::ArchiveEssential.new(**transition_dependencies)

    def transition_dependencies
      { essentials: essential_repository, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, policy:, clock: Time.zone }
    end

    def policy = Policies::Catalog::ManageContentPolicy.new
  end
end

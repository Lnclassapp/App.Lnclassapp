# 🌐 DELIVERY · Teams::LevelsController
# Rôle : niveaux du référentiel : liste par position, création et modification en modale, suppression refusée si utilisé
# ADR  : 0026, 0029, 0034, 0036, 0058 · UDR : 0006, 0032
module Teams
  class LevelsController < BaseController
    helper_method :level_dom_id

    def index
      @levels = levels_query.call
    end

    # Position suivante proposée, et premier cycle coché par défaut (chantier cycles-en-radio).
    def new
      @form = Dtos::Catalog::LevelInput.new(position: levels_query.call.map(&:position).max.to_i + 1,
                                            cycle: Entities::Catalog::Level::CYCLES.first)
    end

    def create
      @form = form_input
      render_result create_level.call(actor: current_actor, dto: @form), form: :new,
                                                                        success: ->(level) { respond_written(level, :created) }
    end

    def edit
      @slug = params[:slug]
      level = levels_query.find(slug: @slug)
      return render_not_found if level.nil?

      @form = Dtos::Catalog::LevelInput.new(name: level.name, position: level.position, cycle: level.cycle)
    end

    def update
      @slug = params[:slug]
      @form = form_input
      render_result update_level.call(actor: current_actor, slug: @slug, dto: @form), form: :edit,
                                                                                      success: ->(level) { respond_written(level, :updated) }
    end

    # Refus d'un niveau utilisé : la ligne reste, le toast en donne la raison. Sinon : toast et ligne retirée.
    def destroy
      result = delete_level.call(actor: current_actor, slug: params[:slug])
      return render_referenced if result.code == :conflict

      render_result result, success: lambda { |_|
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to levels_path, notice: t(".deleted"), status: :see_other }
        end
      }
    end

    private

    # Identifiant de la ligne d'un niveau, par son slug (ADR-0029) : cible des Turbo Streams.
    def level_dom_id(slug) = "level_#{slug}"

    def form_input = Dtos::Catalog::LevelInput.new(params.expect(level: %i[name position cycle]))

    # Le tableau entier est rendu de nouveau : une position modifiée change l'ordre des lignes.
    def respond_written(level, message)
      @level = level
      @levels = levels_query.call
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to levels_path, notice: t(".#{message}", name: level.name), status: :see_other }
      end
    end

    def render_referenced
      @level = levels_query.find(slug: params[:slug])
      @usage = usage_of(@level)
      respond_to do |format|
        format.turbo_stream { render :destroy, status: :unprocessable_entity }
        format.html { redirect_to levels_path, alert: t(".referenced_alert", name: @level.name, usage: @usage), status: :see_other }
      end
    end

    # « 1 série, 2 classes et 1 cours » : seul ce qui retient le niveau est nommé.
    def usage_of(level)
      { series: level.series_names.size, classrooms: level.classrooms_count, courses: level.courses_count }
        .select { |_, count| count.positive? }.map { |usage, count| t(".usage.#{usage}", count:) }.to_sentence
    end

    def levels_query = Queries::Catalog::LevelsQuery.new

    def create_level
      UseCases::Catalog::CreateLevel.new(classroom_plan: Repositories::Classroom::ClassroomPlanRepository.new, **use_case_dependencies)
    end
    def update_level = UseCases::Catalog::UpdateLevel.new(**use_case_dependencies)
    def delete_level = UseCases::Catalog::DeleteLevel.new(**use_case_dependencies)

    def use_case_dependencies
      { taxonomy: Repositories::Catalog::TaxonomyRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, policy: Policies::Catalog::ManageTaxonomyPolicy.new, clock: Time.zone }
    end
  end
end

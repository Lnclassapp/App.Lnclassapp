# 🌐 DELIVERY · Teams::EssentialsController
# Rôle : fiches essentielles d'un cours : création et modification en modale, publication et archivage en Turbo Stream
# ADR  : 0026, 0028, 0035 · UDR : 0006, 0007, 0016
module Teams
  class EssentialsController < BaseController
    before_action :set_course, only: %i[new create]
    before_action :set_essential, only: %i[edit update]

    def new
      @form = Dtos::Catalog::EssentialInput.new(course_slug: @course.slug)
    end

    def create
      @form = form_input(course_slug: @course.slug)
      render_result create_essential.call(actor: current_actor, dto: @form), form: :new,
                    success: ->(essential) { respond_written(essential, :created, course_path(@course.slug)) }
    end

    def edit
      @form = Dtos::Catalog::EssentialInput.new(name: @essential.name, subtitle: @essential.subtitle, content: @essential.content)
    end

    # Sans Turbo, retour au catalogue : la fiche ne connaît que l'identifiant de son cours, pas son slug.
    def update
      @form = form_input
      render_result update_essential.call(actor: current_actor, slug: @essential.slug, dto: @form), form: :edit,
                    success: ->(essential) { respond_written(essential, :updated, courses_path) }
    end

    def publish = transition(publish_essential)
    def archive = transition(archive_essential)

    private

    def set_course
      @course = course_repository.find_by_slug(slug: params[:course_slug])
      render_not_found if @course.nil?
    end

    def set_essential
      @essential = essential_repository.find_by_slug(slug: params[:slug])
      render_not_found if @essential.nil?
    end

    def form_input(**attributes)
      Dtos::Catalog::EssentialInput.new(params.expect(essential: %i[name subtitle content]).merge(attributes))
    end

    # La page hôte (cours, fiche) appartient à d'autres lots : le stream la rafraîchit par morphing.
    def respond_written(essential, message, fallback)
      @essential = essential
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to fallback, notice: t(".#{message}", name: essential.name), status: :see_other }
      end
    end

    # Refus (cours non publié, transition interdite) : 422 et toast d'erreur, le panneau de statut reste tel quel.
    # Sans Turbo, retour à la page d'où le bouton a été cliqué.
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

    def course_repository = Repositories::Catalog::CourseRepository.new
    def essential_repository = Repositories::Catalog::EssentialRepository.new

    def create_essential
      UseCases::Catalog::CreateEssential.new(courses: course_repository, essentials: essential_repository,
                                             transaction: Repositories::Shared::Transaction.new, policy:)
    end

    def update_essential
      UseCases::Catalog::UpdateEssential.new(essentials: essential_repository, transaction: Repositories::Shared::Transaction.new,
                                             policy:)
    end

    def publish_essential = UseCases::Catalog::PublishEssential.new(**transition_dependencies)
    def archive_essential = UseCases::Catalog::ArchiveEssential.new(**transition_dependencies)

    def transition_dependencies
      { essentials: essential_repository, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, policy:, clock: Time.zone }
    end

    def policy = Policies::Catalog::ManageContentPolicy.new
  end
end

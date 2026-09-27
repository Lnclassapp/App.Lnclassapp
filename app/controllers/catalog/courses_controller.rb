# 🌐 DELIVERY · Catalog::CoursesController
# Rôle : catalogue filtré (frame « courses ») et page d'un cours, pour tous les rôles connectés ; non publié : 404 hors équipe
# ADR  : 0026, 0028, 0035 · UDR : 0006, 0013
module Catalog
  class CoursesController < AuthenticatedController
    LIST_FRAME = "courses".freeze
    FILTERS = %i[level material].freeze

    helper_method :list_frame_request?, :filter_options

    def index
      @filters = params.permit(*FILTERS).to_h.symbolize_keys
      @courses = Queries::Catalog::CourseCatalogQuery.new.call(actor: current_actor, **@filters)
    end

    def show
      @detail = Queries::Catalog::CourseDetailQuery.new.call(slug: params[:slug], actor: current_actor)
      return render_not_found if @detail.nil?

      render_result Policies::Catalog::ReadPublishedPolicy.new.call(actor: current_actor, content: @detail.course),
                    success: ->(_) { load_status_record }
    end

    private

    # Le panneau de statut de l'équipe prend l'entité du cours : c'est lui que remplacent les transitions (Lot B2).
    def load_status_record
      return unless Policies::Catalog::ManageContentPolicy.new.call(actor: current_actor).success?

      @status_record = Repositories::Catalog::CourseRepository.new.find_by_slug(slug: params[:slug])
    end

    def list_frame_request? = turbo_frame_request_id == LIST_FRAME
    def filter_options = @filter_options ||= Queries::Catalog::ReferentialOptionsQuery.new.call
  end
end

# 🌐 DELIVERY · Catalog::CoursesController
# Rôle : catalogue filtré (niveau, série, matière), cherché par nom (frame « courses », `q`), par pages chargées au défilement, et page d'un cours ; non publié : 404 hors équipe ; élève : son niveau seul
# ADR  : 0026, 0028, 0035, 0076 · UDR : 0006, 0013 (amendement du 2026-10-05), 0054, 0069
module Catalog
  class CoursesController < AuthenticatedController
    include ReadsOwnLevel

    LIST_FRAME = "courses".freeze
    # Lot E4 (politique-cache, UDR-0013 amendement du 2026-10-05) : la page suivante, demandée par le frame différé posé
    # au bas de la précédente ; elle ne reçoit que ses cartes et le frame de la page d'après.
    PAGE_FRAME = /\Acourses_page_\d+\z/
    FILTERS = %i[level series material q].freeze

    helper_method :list_frame_request?, :filter_options, :student_audience

    def index
      @filters = params.permit(*FILTERS).to_h.symbolize_keys
      # La série ne fait que restreindre : l'élève garde la règle de son niveau (audience).
      @page = Queries::Catalog::CourseCatalogQuery.new.call(actor: current_actor, page: params[:page], level: @filters[:level],
                                                            series: @filters[:series], material: @filters[:material],
                                                            search: @filters[:q],
                                                            audience: (student_audience if current_actor.student?))
      render partial: "page_frame", locals: { page: @page } if page_frame_request?
    end

    def show
      @detail = Queries::Catalog::CourseDetailQuery.new.call(slug: params[:slug], actor: current_actor)
      return render_not_found if @detail.nil?
      return if refuse_out_of_level(course_slug: params[:slug])

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
    def page_frame_request? = PAGE_FRAME.match?(turbo_frame_request_id.to_s)
    def filter_options = @filter_options ||= Queries::Catalog::ReferentialOptionsQuery.new.call
  end
end

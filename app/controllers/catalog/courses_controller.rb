# 🌐 DELIVERY · Catalog::CoursesController
# Rôle : catalogue filtré et cherché par nom (frame « courses ») et page d'un cours ; non publié : 404 hors équipe ; élève : son niveau ; enseignant : sa matière à ses niveaux
# ADR  : 0026, 0028, 0035 · UDR : 0006, 0013, 0054, 0069, 0077
module Catalog
  class CoursesController < AuthenticatedController
    include ReadsOwnLevel

    LIST_FRAME = "courses".freeze
    FILTERS = %i[level series material q].freeze

    helper_method :list_frame_request?, :filter_options, :student_audience, :teacher_scope

    def index
      @filters = params.permit(*FILTERS).to_h.symbolize_keys
      # La série ne fait que restreindre : l'élève garde la règle de son niveau (audience).
      @courses = Queries::Catalog::CourseCatalogQuery.new.call(actor: current_actor, level: @filters[:level],
                                                               series: @filters[:series], material: @filters[:material],
                                                               search: @filters[:q], audience: own_audience,
                                                               material_id: teacher_scope&.material_id)
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

    # UDR-0077 §3.2 : l'élève lit son niveau, l'enseignant sa matière aux niveaux de ses classes ; les autres, tout.
    def own_audience
      return student_audience if current_actor.student?

      teacher_scope&.audience
    end

    def teacher_scope
      return unless current_actor.teacher?

      @teacher_scope ||= Queries::Catalog::TeacherAudienceQuery.new.call(teacher_id: current_actor.user_id)
    end

    def list_frame_request? = turbo_frame_request_id == LIST_FRAME
    def filter_options = @filter_options ||= Queries::Catalog::ReferentialOptionsQuery.new.call
  end
end

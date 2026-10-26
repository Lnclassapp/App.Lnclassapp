# 🌐 DELIVERY · Catalog::CoursesController
# Rôle : catalogue filtré, cherché par nom (frame « courses »), par pages chargées au défilement, et page d'un cours ; élève : son niveau, groupé par matière, vue d'une matière ; enseignant : une de ses matières à la fois, au niveau du rond de l'accueil
# ADR  : 0026, 0028, 0035, 0076, 0090, 0094, 0103 · UDR : 0006, 0013 (amendement du 2026-10-05), 0054, 0069, 0077, 0085, 0126, XXXX écrans enseignant sans répétition §3.7
module Catalog
  class CoursesController < AuthenticatedController
    include ReadsOwnLevel

    LIST_FRAME = "courses".freeze
    # Lot E4 (politique-cache, UDR-0013 amendement du 2026-10-05) : la page suivante, demandée par le frame différé posé
    # au bas de la précédente ; elle ne reçoit que ses cartes et le frame de la page d'après.
    PAGE_FRAME = /\Acourses_page_\d+\z/
    FILTERS = %i[level series material q].freeze

    helper_method :list_frame_request?, :filter_options, :student_audience, :teacher_scope, :teacher_grouped?, :student_material,
                  :after_material, :teacher_material, :teacher_level_label

    def index
      @filters = params.permit(*FILTERS).to_h.symbolize_keys
      # UDR enseignant §3.7 : une matière à la fois, la puce active (par défaut la première) ; la page suivante la reprend.
      @filters[:material] = teacher_material&.slug if teacher_scope
      # La série ne fait que restreindre : l'élève garde la règle de son niveau (audience).
      @page = Queries::Catalog::CourseCatalogQuery.new.call(actor: current_actor, page: params[:page], level: @filters[:level],
                                                            series: @filters[:series], material: @filters[:material],
                                                            search: @filters[:q], audience: own_audience,
                                                            material_ids: teacher_scope&.material_ids)
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

    # UDR-0077 §3.2 : l'élève lit son niveau, l'enseignant sa matière aux niveaux de ses classes ; les autres, tout.
    def own_audience
      return student_audience if current_actor.student?

      teacher_scope&.audience
    end

    def teacher_scope
      return unless current_actor.teacher?

      @teacher_scope ||= Queries::Catalog::TeacherAudienceQuery.new.call(teacher_id: current_actor.user_id,
                                                                         school_id: current_actor.school_id)
    end

    # UDR enseignant §3.7 (amende UDR-0126 §3.1) : l'enseignant ne voit qu'une matière à la fois, sans groupes. La page
    # partagée (_page) garde sa branche « groupes » pour l'élève seulement.
    def teacher_grouped? = false

    # La matière de la puce active : celle de l'adresse si c'en est une des siennes dans l'établissement courant, sinon la
    # première ; nil sans matière (l'état vide l'explique).
    def teacher_material
      return unless teacher_scope

      @teacher_material ||= teacher_scope.materials.find { it.slug == @filters[:material] } || teacher_scope.materials.first
    end

    # « Tle D » : le niveau de l'adresse (un rond de l'accueil) et sa série quand ce niveau la permet ; nil sans niveau connu.
    def teacher_level_label
      level = filter_options.levels.find { it.slug == @filters[:level] }
      return unless level

      series = filter_options.series_by_level.fetch(level.id, []).find { it.slug == @filters[:series] }
      [ level.name, series&.name ].compact.join(" ")
    end

    # UDR-0085 §3.1 : la vue d'une matière de l'élève (?material=<slug>, l'adresse des bulles « Mes matières ») ; nil sur
    # la liste complète, pour un autre rôle ou pour un slug inconnu.
    def student_material
      return unless current_actor.student? && @filters[:material].present?

      @student_material ||= filter_options.materials.find { it.slug == @filters[:material] }
    end

    # UDR-0085 §3.2 : la matière de la dernière carte de la page précédente, dont le titre de groupe est déjà rendu.
    # Toujours une chaîne : une valeur forgée (tableau, vide) ne vaut aucun slug, et le titre reste rendu.
    def after_material = params[:after_material].to_s

    def list_frame_request? = turbo_frame_request_id == LIST_FRAME
    def page_frame_request? = PAGE_FRAME.match?(turbo_frame_request_id.to_s)
    def filter_options = @filter_options ||= Queries::Catalog::ReferentialOptionsQuery.new.call
  end
end

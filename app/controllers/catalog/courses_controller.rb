# 🌐 DELIVERY · Catalog::CoursesController
# Rôle : catalogue filtré, cherché par nom (frame « courses »), par pages chargées au défilement, et page d'un cours ; élève : son niveau, groupé par matière, vue d'une matière, et sur ordinateur ses leçons par matière (la dernière touchée, gardée en session) ; enseignant : ses matières à ses niveaux
# ADR  : 0026, 0028, 0035, 0076, 0090, 0094, 0103 · UDR : 0006, 0013 (amendement du 2026-10-05), 0054, 0069, 0077, 0085, 0126, XXXX écrans élève sans répétition §3.6 bis
module Catalog
  class CoursesController < AuthenticatedController
    include ReadsOwnLevel

    LIST_FRAME = "courses".freeze
    # Lot E4 (politique-cache, UDR-0013 amendement du 2026-10-05) : la page suivante, demandée par le frame différé posé
    # au bas de la précédente ; elle ne reçoit que ses cartes et le frame de la page d'après.
    PAGE_FRAME = /\Acourses_page_\d+\z/
    FILTERS = %i[level series material q].freeze

    # Lot O5 (CA-E15) : le slug de la dernière matière que l'élève a ouverte, gardé en session pour « Cours » sans ?material=.
    LESSON_MATERIAL_KEY = :courses_lesson_material

    helper_method :list_frame_request?, :filter_options, :student_audience, :teacher_scope, :teacher_grouped?, :student_material,
                  :after_material, :lesson_materials, :lesson_material, :lessons_page

    def index
      @filters = params.permit(*FILTERS).to_h.symbolize_keys
      # La série ne fait que restreindre : l'élève garde la règle de son niveau (audience).
      @page = Queries::Catalog::CourseCatalogQuery.new.call(actor: current_actor, page: params[:page], level: @filters[:level],
                                                            series: @filters[:series], material: @filters[:material],
                                                            search: @filters[:q], audience: own_audience,
                                                            material_ids: teacher_scope&.material_ids,
                                                            group_by_material: teacher_grouped?)
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

    # UDR-0126 §3.1 : l'enseignant de plusieurs matières voit ses cours rangés par matière, comme l'élève.
    def teacher_grouped? = teacher_scope&.several_materials? || false

    # UDR-0085 §3.1 : la vue d'une matière de l'élève (?material=<slug>, l'adresse des bulles « Mes matières ») ; nil sur
    # la liste complète, pour un autre rôle ou pour un slug inconnu.
    def student_material
      return unless current_actor.student? && @filters[:material].present?

      @student_material ||= filter_options.materials.find { it.slug == @filters[:material] }
    end

    # UDR-0085 §3.2 : la matière de la dernière carte de la page précédente, dont le titre de groupe est déjà rendu.
    # Toujours une chaîne : une valeur forgée (tableau, vide) ne vaut aucun slug, et le titre reste rendu.
    def after_material = params[:after_material].to_s

    # Lot O5 (CA-E15) : les matières de l'élève (celles de sa classe), dans l'ordre de la grille de l'accueil ; [] sinon.
    def lesson_materials
      return [] unless current_actor.student?

      @lesson_materials ||= Queries::Catalog::CourseCatalogQuery.new.student_materials(audience: student_audience)
    end

    # CA-E15 : la matière des leçons affichées sur ordinateur. ?material= vaut seulement s'il est l'une des matières de
    # l'élève, et il est alors gardé ; sinon la dernière gardée si elle l'est encore, sinon la première de la grille. Un slug
    # inconnu ou d'une autre classe n'est ni lu ni gardé.
    def lesson_material
      return if lesson_materials.empty?

      @lesson_material ||= begin
        requested = lesson_materials.find { it.slug == @filters[:material] }
        session[LESSON_MATERIAL_KEY] = requested.slug if requested
        requested || lesson_materials.find { it.slug == session[LESSON_MATERIAL_KEY] } || lesson_materials.first
      end
    end

    # CA-E14 : les leçons de cette matière avec leurs fiches, sur la recherche ; nil sans matière (élève sans classe).
    def lessons_page
      return unless lesson_material

      @lessons_page ||= Queries::Catalog::CourseCatalogQuery.new.call(actor: current_actor, material: lesson_material.slug,
                                                                      search: @filters[:q], audience: student_audience,
                                                                      with_essentials: true)
    end

    def list_frame_request? = turbo_frame_request_id == LIST_FRAME
    def page_frame_request? = PAGE_FRAME.match?(turbo_frame_request_id.to_s)
    def filter_options = @filter_options ||= Queries::Catalog::ReferentialOptionsQuery.new.call
  end
end

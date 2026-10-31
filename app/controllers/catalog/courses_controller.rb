# 🌐 DELIVERY · Catalog::CoursesController
# Rôle : catalogue filtré, cherché par nom (frame « courses »), par pages chargées au défilement, et page d'un cours ; élève : son niveau, groupé par matière, vue d'une matière, et sur ordinateur ses leçons par matière (la dernière touchée, gardée en session) ; enseignant : une de ses matières à la fois, au niveau du rond de l'accueil
# ADR  : 0121, 0026, 0028, 0035, 0076, 0090, 0094, 0103 · UDR : 0006, 0013 (amendement du 2026-10-05), 0054, 0069, 0077, 0085, 0126, XXXX écrans enseignant sans répétition §3.7, XXXX écrans élève sans répétition §3.6 bis, 0144 parcours matière → exercice §3, 0148 §3
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

    helper_method :list_frame_request?, :filter_options, :student_audience, :teacher_scope, :student_material,
                  :after_material, :teacher_material, :teacher_level_label, :lesson_materials, :lesson_material, :lessons_page,
                  :next_exercise_for

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
                    success: ->(_) { load_status_record; load_lesson_sections; load_next_exercise; record_reads }
    end

    # CA-12 : l'ancienne adresse de la fiche de cours mène à la fiche de révision de la page de la leçon (301) ; mêmes refus
    # que la page (404, rien de révélé).
    def fiche
      detail = Queries::Catalog::CourseDetailQuery.new.call(slug: params[:course_slug], actor: current_actor)
      return render_not_found if detail.nil?
      return if refuse_out_of_level(course_slug: params[:course_slug])

      render_result Policies::Catalog::ReadPublishedPolicy.new.call(actor: current_actor, content: detail.course),
                    success: ->(_) { redirect_to course_path(params[:course_slug], anchor: "fiche-de-revision"), status: :moved_permanently }
    end

    private

    # UDR page de la leçon : les deux sections, lues pour le rôle courant (squelettes du Lot 0).
    def load_lesson_sections
      @revision = Queries::Catalog::RevisionSheetQuery.new.call(course_slug: params[:slug], actor: current_actor)
      @prepare = Queries::Catalog::PrepareSheetsQuery.new.call(course_slug: params[:slug], actor: current_actor)
    end

    # UDR parcours matière → exercice §3 : la carte « Prochain exercice » de la leçon, pour l'élève seulement.
    def load_next_exercise
      return unless current_actor.student?

      @next_exercise = Queries::Catalog::NextExerciseQuery.new.call(student_id: current_actor.user_id, audience: student_audience,
                                                                    course_slug: params[:slug])
    end

    # ADR-0113 §4.3 (amende ADR-0090 §4.1) : ouvrir la leçon retient, pour l'élève, la lecture de chacune de ses notions publiées.
    # Turbo précharge un lien au survol ou au toucher (X-Sec-Purpose: prefetch) : ce n'est pas une ouverture. Une panne de la
    # base ne bloque jamais la page : le use case la signale (config/initializers/error_reporting.rb). Les Result sont ignorés
    # exprès : la policy de lecture a déjà répondu plus haut et la panne est déjà signalée.
    def record_reads
      return unless current_actor.student? && !prefetch?

      essentials = Repositories::Catalog::EssentialRepository.new
      @detail.essentials.each do |row|
        essential = essentials.find_by_slug(slug: row.slug)
        # Une notion supprimée pendant la lecture n'est plus à lire : la page s'affiche quand même.
        record_read(essential) unless essential.nil?
      end
    end

    def record_read(essential)
      UseCases::Assessment::RecordEssentialRead.new(
        reads: Repositories::Assessment::EssentialReadRepository.new, policy: Policies::Catalog::ReadPublishedPolicy.new,
        reporter: Rails.error, recoverable: Repositories::Assessment::EssentialReadRepository::OUTAGES, clock: Time.zone
      ).call(actor: current_actor, essential:)
    end

    def prefetch?
      %w[X-Sec-Purpose Sec-Purpose Purpose].any? { request.headers[it].to_s.include?("prefetch") }
    end

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

    # Lot O5 (CA-E15) : les matières de l'élève (celles de sa classe), dans l'ordre de la grille de l'accueil. Lu par la vue de
    # l'élève seulement (index : « if student »).
    def lesson_materials
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

    # UDR parcours matière → exercice §3 : la carte de la vue d'une matière ; lue par les blocs de l'élève seulement (index :
    # « if student », là où student_material et lesson_material existent), une fois par matière même si le téléphone et
    # l'ordinateur visent la même.
    def next_exercise_for(material_slug)
      @next_exercises ||= {}
      return @next_exercises[material_slug] if @next_exercises.key?(material_slug)

      @next_exercises[material_slug] = Queries::Catalog::NextExerciseQuery.new.call(
        student_id: current_actor.user_id, audience: student_audience, material: material_slug
      )
    end

    def list_frame_request? = turbo_frame_request_id == LIST_FRAME
    def page_frame_request? = PAGE_FRAME.match?(turbo_frame_request_id.to_s)
    def filter_options = @filter_options ||= Queries::Catalog::ReferentialOptionsQuery.new.call
  end
end

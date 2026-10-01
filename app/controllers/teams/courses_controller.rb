# 🌐 DELIVERY · Teams::CoursesController
# Rôle : l'équipe crée et modifie un cours en modale (éditeur riche), le publie, l'archive ou publie tout son contenu (menu ⋮)
# ADR  : 0026, 0035, 0037 · UDR : 0006, 0014
module Teams
  class CoursesController < BaseController
    include PublishCascade

    FIELDS = %i[name subtitle level_slug series_slug material_slug content].freeze

    before_action :load_options, only: %i[new create edit update]

    def new
      @form = Dtos::Catalog::CourseInput.new
    end

    # Succès : toast, modale refermée, page hôte (catalogue de B1) re-demandée et fusionnée par morphing.
    def create
      @form = form_input
      render_result create_course.call(actor: current_actor, dto: @form), form: :new,
                                                                          success: ->(course) { respond_written(course, :created) }
    end

    def edit
      @course = courses.find_by_slug(slug: params[:slug])
      return render_not_found if @course.nil?

      @form = Dtos::Catalog::CourseInput.new(
        name: @course.name, subtitle: @course.subtitle, content: @course.content,
        level_slug: slug_of(@options.levels, @course.level_id), material_slug: slug_of(@options.materials, @course.material_id),
        series_slug: slug_of(@options.series_by_level.values.flatten, @course.series_id)
      )
    end

    def update
      @course = courses.find_by_slug(slug: params[:slug])
      @form = form_input
      render_result update_course.call(actor: current_actor, slug: params[:slug], dto: @form), form: :edit,
                                                                                               success: ->(course) { respond_written(course, :updated) }
    end

    def publish = transition(publish_course)
    def archive = transition(archive_course)

    private

    def cascade_root = :course

    def respond_written(course, message)
      @course = course
      respond_to do |format|
        format.turbo_stream
        format.html do
          redirect_to course_path(course.slug), notice: t("teams.courses.#{action_name}.#{message}", name: course.name), status: :see_other
        end
      end
    end

    # Transition refusée (:conflict) : 422, toast d'erreur et panneau re-rendu dans l'état relu.
    def transition(use_case)
      result = use_case.call(actor: current_actor, slug: params[:slug])
      return respond_refused if result.code == :conflict

      render_result result, success: lambda { |course|
        @course = course
        respond_to do |format|
          format.turbo_stream { render :transition }
          format.html { redirect_to course_path(course.slug), notice: t("teams.courses.transition.#{course.status}", name: course.name), status: :see_other }
        end
      }
    end

    def respond_refused
      @course = courses.find_by_slug(slug: params[:slug])
      @refused = true
      respond_to do |format|
        format.turbo_stream { render :transition, status: :unprocessable_entity }
        format.html { redirect_to course_path(@course.slug), alert: t("teams.courses.transition.refused", name: @course.name), status: :see_other }
      end
    end

    def slug_of(rows, id)
      row = rows.find { |item| item.id == id }
      row.slug if row
    end

    def load_options
      @options = Queries::Catalog::ReferentialOptionsQuery.new.call
    end

    def form_input = Dtos::Catalog::CourseInput.new(params.expect(course: FIELDS).to_h.symbolize_keys)

    def courses = @courses ||= Repositories::Catalog::CourseRepository.new
    def policy = Policies::Catalog::ManageContentPolicy.new

    def create_course = UseCases::Catalog::CreateCourse.new(courses:, taxonomy: Repositories::Catalog::TaxonomyRepository.new, policy:)
    def update_course = UseCases::Catalog::UpdateCourse.new(courses:, taxonomy: Repositories::Catalog::TaxonomyRepository.new, policy:)
    def publish_course = UseCases::Catalog::PublishCourse.new(**transition_dependencies)
    def archive_course = UseCases::Catalog::ArchiveCourse.new(**transition_dependencies)

    def transition_dependencies
      { courses:, audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
        policy:, clock: Time.zone }
    end
  end
end

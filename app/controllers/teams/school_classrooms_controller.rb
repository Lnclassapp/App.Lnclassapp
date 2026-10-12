# 🌐 DELIVERY · Teams::SchoolClassroomsController
# Rôle : l'équipe ajoute une classe à un établissement, en modale ouverte depuis sa fiche ; le code d'adhésion est tiré à la création
# ADR  : 0026, 0028, 0030, 0041 · UDR : 0006, 0031
module Teams
  class SchoolClassroomsController < BaseController
    FIELDS = %i[level_slug series_slug name max_students].freeze

    before_action :load_school, :load_options
    helper_method :level_choices, :series_choices

    def new
      @form = Dtos::Classroom::ClassroomInput.new(school_public_id: @school.public_id)
    end

    # Succès : toast avec le nom de la classe, modale refermée, fiche de l'établissement (S2) re-demandée et fusionnée par morphing.
    def create
      @form = form_input
      render_result create_classroom.call(actor: current_actor, dto: @form), form: :new,
                                                                             success: ->(classroom) { respond_created(classroom) }
    end

    private

    def respond_created(classroom)
      @classroom = classroom
      respond_to do |format|
        format.turbo_stream
        format.html do
          redirect_to classroom_path(classroom.public_id), notice: t(".created", name: classroom.name), status: :see_other
        end
      end
    end

    def load_school
      @school = Queries::School::SchoolsQuery.new.find(public_id: params[:school_public_id])
      render_not_found if @school.nil?
    end

    def load_options
      @options = Queries::Catalog::ReferentialOptionsQuery.new.call
    end

    # Un collège (cycle « first ») n'a que les niveaux du premier cycle, comme à la génération.
    def offered_levels
      return @options.levels unless @school.cycle == "first"

      @options.levels.select { it.cycle == "first" }
    end

    def level_choices = offered_levels.map { [ it.name, it.slug ] }

    # Séries rangées sous leur niveau : seuls les couples ouverts sont proposés.
    def series_choices
      offered_levels.filter_map do |level|
        series = @options.series_by_level[level.id]
        [ level.name, series.map { [ it.name, it.slug ] } ] if series
      end
    end

    def form_input
      Dtos::Classroom::ClassroomInput.new(school_public_id: @school.public_id,
                                          **params.expect(classroom: FIELDS).to_h.symbolize_keys)
    end

    def create_classroom
      UseCases::Classroom::CreateClassroom.new(
        classrooms: Repositories::Classroom::ClassroomRepository.new, schools: Repositories::School::SchoolRepository.new,
        taxonomy: Repositories::Catalog::TaxonomyRepository.new, policy: Policies::Classroom::ManageClassroomPolicy.new,
        clock: Time.zone
      )
    end
  end
end

# 🌐 DELIVERY · Teams::LevelClassroomsController
# Rôle : « + » (classe suivante d'un niveau) et « − » (dernière classe, confirmée) du bloc « Classes par niveau » de la fiche
# ADR  : 0028, 0036, 0041, 0059, 0071 · UDR : 0006, 0046
module Teams
  class LevelClassroomsController < BaseController
    # Un refus garde son statut HTTP ; tout autre motif (conflit, saisie) est un 422.
    FAILURE_STATUSES = { forbidden: :forbidden, not_found: :not_found }.freeze

    before_action :load_block

    def create
      result = build(UseCases::Classroom::AddLevelClassroom, taxonomy: Repositories::Catalog::TaxonomyRepository.new)
               .call(actor: current_actor, school_public_id: @block.school_public_id, level_slug: params[:level],
                     series_slug: params[:series])
      respond(result) { |classroom| t(".done", name: classroom.name) }
    end

    def destroy
      result = build(UseCases::Classroom::RemoveLevelClassroom)
               .call(actor: current_actor, school_public_id: @block.school_public_id, classroom_public_id: params[:public_id])
      respond(result) { |classroom| t(".done", name: classroom.name) }
    end

    private

    # Succès : toast, bloc remplacé, fiche re-demandée (titre et cartes). Refus : toast au motif, bloc re-rendu (la
    # confirmation se referme), rien d'autre ne bouge.
    def respond(result)
      @notice = yield(result.value) if result.success?
      @alert = t("teams.level_classrooms.errors.#{result.errors.fetch(:base, [ result.code ]).first}") if result.failure?
      load_block
      respond_to do |format|
        format.turbo_stream { render :update, status: failure_status(result) }
        format.html { redirect_to school_path(@block.school_public_id), notice: @notice, alert: @alert, status: :see_other }
      end
    end

    def failure_status(result) = result.success? ? :ok : FAILURE_STATUSES.fetch(result.code, :unprocessable_entity)

    def load_block
      @block = Queries::School::LevelClassroomsQuery.new.call(public_id: params[:school_public_id])
      render_not_found if @block.nil?
    end

    def build(use_case, **dependencies)
      use_case.new(classrooms: Repositories::Classroom::ClassroomRepository.new, schools: Repositories::School::SchoolRepository.new,
                   audit_log: Repositories::Identity::AuditLogRepository.new, policy: Policies::School::ManageSchoolStructurePolicy.new,
                   transaction: Repositories::Shared::Transaction.new, clock: Time.zone, **dependencies)
    end
  end
end

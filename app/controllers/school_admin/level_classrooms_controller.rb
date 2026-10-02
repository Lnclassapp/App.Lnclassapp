# 🌐 DELIVERY · SchoolAdmin::LevelClassroomsController
# Rôle : « + » et « − » du bloc « Classes par niveau » de « Établissement », sur le seul établissement de la direction
# ADR  : 0059, 0065, 0071 · UDR : 0046, 0056 · l'établissement est current_actor.school_id, jamais un paramètre
module SchoolAdmin
  class LevelClassroomsController < BaseController
    # Un refus garde son statut HTTP ; tout autre motif (conflit, saisie) est un 422.
    FAILURE_STATUSES = { forbidden: :forbidden, not_found: :not_found }.freeze

    before_action :load_school

    def create
      result = build(UseCases::Classroom::AddLevelClassroom, taxonomy: Repositories::Catalog::TaxonomyRepository.new)
               .call(actor: current_actor, school_public_id: @school.public_id, level_slug: params[:level],
                     series_slug: params[:series])
      respond(result) do |classroom|
        t("teams.level_classrooms.create.done", name: classroom.name, code: Entities::Classroom::JoinCode.display(classroom.join_code))
      end
    end

    # Une classe d'un autre établissement : le use case ne la trouve pas dans celui de la direction → 404.
    def destroy
      result = build(UseCases::Classroom::RemoveLevelClassroom)
               .call(actor: current_actor, school_public_id: @school.public_id, classroom_public_id: params[:public_id])
      respond(result) { |classroom| t("teams.level_classrooms.destroy.done", name: classroom.name) }
    end

    private

    # Succès : toast, bloc remplacé. Refus : toast au motif de l'équipe, bloc re-rendu (la confirmation se referme).
    def respond(result)
      @notice = yield(result.value) if result.success?
      @alert = t("teams.level_classrooms.errors.#{result.errors.fetch(:base, [ result.code ]).first}") if result.failure?
      @block = Queries::School::LevelClassroomsQuery.new.call(public_id: @school.public_id)
      respond_to do |format|
        format.turbo_stream { render :update, status: failure_status(result) }
        format.html { redirect_to school_admin_school_path, notice: @notice, alert: @alert, status: :see_other }
      end
    end

    def failure_status(result) = result.success? ? :ok : FAILURE_STATUSES.fetch(result.code, :unprocessable_entity)

    def load_school
      @school = Queries::School::OwnSchoolQuery.new.call(school_id: current_actor.school_id)
    end

    def build(use_case, **dependencies)
      use_case.new(classrooms: Repositories::Classroom::ClassroomRepository.new, schools: Repositories::School::SchoolRepository.new,
                   audit_log: Repositories::Identity::AuditLogRepository.new, policy: Policies::School::ManageSchoolStructurePolicy.new,
                   transaction: Repositories::Shared::Transaction.new, clock: Time.zone, **dependencies)
    end
  end
end

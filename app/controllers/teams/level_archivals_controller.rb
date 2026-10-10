# 🌐 DELIVERY · Teams::LevelArchivalsController
# Rôle : « Archiver le niveau » du menu ⋮ de l'en-tête d'un niveau de la fiche : archive d'un coup ses classes actives
# ADR  : 0028, 0059, 0071, 0088 · UDR : 0083
module Teams
  class LevelArchivalsController < BaseController
    # Un refus garde son statut HTTP ; tout autre motif (rien à archiver) est un 422.
    FAILURE_STATUSES = { forbidden: :forbidden, not_found: :not_found }.freeze

    def create
      level = Repositories::Catalog::TaxonomyRepository.new.lookup.level(params[:level])
      result = level ? archive(level) : ::Shared::Result.failure(:not_found)
      @school = Queries::School::SchoolDetailQuery.new.call(public_id: params[:school_public_id])
      return render_not_found if @school.nil?

      @notice = t(".done", count: result.value) if result.success?
      @alert = t("teams.level_archivals.errors.#{result.errors.fetch(:base, [ result.code ]).first}") if result.failure?
      @level = @school.levels.find { it.slug == params[:level] }
      respond_to do |format|
        format.turbo_stream { render status: result.success? ? :ok : FAILURE_STATUSES.fetch(result.code, :unprocessable_entity) }
        format.html { redirect_to school_path(@school.public_id), notice: @notice, alert: @alert, status: :see_other }
      end
    end

    private

    def archive(level)
      use_case = UseCases::Classroom::ArchiveLevelClassrooms.new(
        classrooms: Repositories::Classroom::ClassroomRepository.new, schools: Repositories::School::SchoolRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, policy: Policies::School::ManageSchoolStructurePolicy.new,
        transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
      use_case.call(actor: current_actor, school_public_id: params[:school_public_id], level_id: level.id)
    end
  end
end

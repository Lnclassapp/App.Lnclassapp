# 🌐 DELIVERY · Teams::ClassroomArchivalsController
# Rôle : « Archiver la classe » et « Restaurer la classe » du menu ⋮ d'une carte de la fiche d'un établissement
# ADR  : 0028, 0059, 0071, 0088 · UDR : 0083
module Teams
  class ClassroomArchivalsController < BaseController
    # Un refus garde son statut HTTP ; tout autre motif (déjà archivée, pas archivée) est un 422.
    FAILURE_STATUSES = { forbidden: :forbidden, not_found: :not_found }.freeze

    def archive = act(UseCases::Classroom::ArchiveClassroom)
    def restore = act(UseCases::Classroom::RestoreClassroom)

    private

    # Succès : toast (avec « Annuler » après un archivage), carte et niveau remplacés, fiche re-demandée. Refus : toast au
    # motif et niveau re-rendu (« déjà archivée » rafraîchit la carte). Sans JavaScript : retour à la fiche avec un message.
    def act(use_case)
      result = build(use_case).call(actor: current_actor, school_public_id: params[:school_public_id], classroom_public_id: params[:public_id])
      @school = Queries::School::SchoolDetailQuery.new.call(public_id: params[:school_public_id])
      return render_not_found if @school.nil?

      @notice = t(".done", name: result.value.name) if result.success?
      @alert = t("teams.classroom_archivals.errors.#{result.errors.fetch(:base, [ result.code ]).first}") if result.failure?
      @level = @school.levels.find { |level| (level.classrooms + level.archived).any? { it.public_id == params[:public_id] } }
      respond_to do |format|
        format.turbo_stream { render status: result.success? ? :ok : FAILURE_STATUSES.fetch(result.code, :unprocessable_entity) }
        format.html { redirect_to school_path(@school.public_id), notice: @notice, alert: @alert, status: :see_other }
      end
    end

    def build(use_case)
      use_case.new(classrooms: Repositories::Classroom::ClassroomRepository.new, schools: Repositories::School::SchoolRepository.new,
                   audit_log: Repositories::Identity::AuditLogRepository.new, policy: Policies::School::ManageSchoolStructurePolicy.new,
                   transaction: Repositories::Shared::Transaction.new, clock: Time.zone)
    end
  end
end

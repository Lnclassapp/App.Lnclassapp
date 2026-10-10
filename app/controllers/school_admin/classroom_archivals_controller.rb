# 🌐 DELIVERY · SchoolAdmin::ClassroomArchivalsController
# Rôle : « Archiver la classe » et « Restaurer la classe » du menu ⋮ d'une carte, sur le seul établissement de la direction
# ADR  : 0065, 0071, 0088 · UDR : 0083 · l'établissement est current_actor.school_id, jamais un paramètre
module SchoolAdmin
  class ClassroomArchivalsController < BaseController
    before_action :load_school

    def archive = act(UseCases::Classroom::ArchiveClassroom)

    def restore = act(UseCases::Classroom::RestoreClassroom)

    private

    # Droit ou classe introuvable : la page d'erreur (toast en Turbo). Conflit (déjà archivée, pas archivée) : toast neutre,
    # la page se rafraîchit pour montrer l'état réel. Succès : toast, page rafraîchie ; l'archivage offre « Annuler ».
    def act(use_case)
      result = use_case.new(classrooms: Repositories::Classroom::ClassroomRepository.new, schools: Repositories::School::SchoolRepository.new,
                            audit_log: Repositories::Identity::AuditLogRepository.new, policy: Policies::School::ManageSchoolStructurePolicy.new,
                            transaction: Repositories::Shared::Transaction.new, clock: Time.zone)
                       .call(actor: current_actor, school_public_id: @school.public_id, classroom_public_id: params[:public_id])
      return render_error_page(result.code) if %i[forbidden not_found].include?(result.code)

      respond(result)
    end

    def respond(result)
      if result.success?
        @notice = t(".done", name: result.value.name)
        @undo = { label: t(".undo"), href: restore_school_admin_classroom_archival_path(result.value.public_id), method: :patch } if action_name == "archive"
      else
        @alert = t("school_admin.classroom_archivals.errors.#{result.errors.fetch(:base).first}")
      end
      respond_to do |format|
        format.turbo_stream { render action_name, status: result.success? ? :ok : :unprocessable_entity }
        format.html { redirect_back_or_to school_admin_classrooms_path, notice: @notice, alert: @alert, status: :see_other }
      end
    end

    def load_school
      @school = Queries::School::OwnSchoolQuery.new.call(school_id: current_actor.school_id)
    end
  end
end

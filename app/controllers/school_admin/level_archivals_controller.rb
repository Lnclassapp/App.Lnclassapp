# 🌐 DELIVERY · SchoolAdmin::LevelArchivalsController
# Rôle : « Archiver le niveau » du menu ⋮ de la page d'un niveau : ses classes actives de l'année, sur le seul établissement de la direction
# ADR  : 0065, 0071, 0088 · UDR : 0083 · le niveau vient de son slug figé, l'établissement de current_actor.school_id
module SchoolAdmin
  class LevelArchivalsController < BaseController
    def create
      level = Repositories::Catalog::TaxonomyRepository.new.lookup.level(params[:level].to_s)
      return render_not_found if level.nil?

      result = archive_level(level)
      return render_error_page(result.code) if %i[forbidden not_found].include?(result.code)

      respond(result, level)
    end

    private

    def archive_level(level)
      school = Queries::School::OwnSchoolQuery.new.call(school_id: current_actor.school_id)
      UseCases::Classroom::ArchiveLevelClassrooms.new(
        classrooms: Repositories::Classroom::ClassroomRepository.new, schools: Repositories::School::SchoolRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, policy: Policies::School::ManageSchoolStructurePolicy.new,
        transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      ).call(actor: current_actor, school_public_id: school.public_id, level_id: level.id)
    end

    def respond(result, level)
      if result.success?
        @notice = t(".done", count: result.value, name: level.name)
      else
        @alert = t("school_admin.level_archivals.errors.#{result.errors.fetch(:base).first}")
      end
      respond_to do |format|
        format.turbo_stream { render :create, status: result.success? ? :ok : :unprocessable_entity }
        format.html { redirect_to school_admin_level_path(level.slug), notice: @notice, alert: @alert, status: :see_other }
      end
    end
  end
end

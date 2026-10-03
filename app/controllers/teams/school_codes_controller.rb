# 🌐 DELIVERY · Teams::SchoolCodesController
# Rôle : régénère le code d'établissement depuis la fiche : toast avec le nouveau code, en-tête remplacé ; repli HTML vers la fiche
# ADR  : 0026, 0028, 0057, 0071 · UDR : 0036, 0042, 0044
module Teams
  class SchoolCodesController < BaseController
    helper_method :school_status_tone

    def update
      result = regenerate.call(actor: current_actor, public_id: params[:school_public_id])
      render_result result, success: lambda { |school|
        @school = Queries::School::SchoolsQuery.new.find(public_id: school.public_id)
        @notice = t(".done", code: Entities::School::SchoolCode.display(school.school_code))
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to school_path(school.public_id), notice: @notice, status: :see_other }
        end
      }
    end

    private

    def school_status_tone(status) = SchoolsController::STATUS_TONES.fetch(status)

    def regenerate
      UseCases::School::RegenerateSchoolCode.new(
        schools: Repositories::School::SchoolRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        policy: Policies::School::ManageSchoolStructurePolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end

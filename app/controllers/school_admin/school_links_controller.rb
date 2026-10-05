# 🌐 DELIVERY · SchoolAdmin::SchoolLinksController
# Rôle : « Changer le lien » d'« Établissement » : nouveau code de l'établissement du compte, bloc du lien remplacé, toast
# ADR  : 0057, 0071 · UDR : 0006, 0056 · l'établissement est current_actor.school_id, jamais un paramètre
module SchoolAdmin
  class SchoolLinksController < BaseController
    # Un refus garde son statut HTTP ; un tirage sans code libre (:conflict) est un 422.
    FAILURE_STATUSES = { forbidden: :forbidden, not_found: :not_found }.freeze

    def update
      result = regenerate.call(actor: current_actor, public_id: own_school.public_id)
      return refuse(result.code) if result.failure?

      @school = own_school
      @notice = t(".done", code: Entities::School::SchoolCode.display(@school.school_code))
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to school_admin_school_path, notice: @notice, status: :see_other }
      end
    end

    private

    # Turbo Stream : toast au motif, bloc re-rendu (la confirmation se referme, le bouton suit le statut). HTML : pages
    # 403/404 communes ; un conflit revient à la page avec son motif.
    def refuse(code)
      @school = own_school
      @alert = t("school_admin.shared.errors.#{code}", default: :"school_admin.school_links.update.#{code}")
      respond_to do |format|
        format.turbo_stream { render :update, status: FAILURE_STATUSES.fetch(code, :unprocessable_entity) }
        format.html do
          next render_error_page(code) if FAILURE_STATUSES.key?(code)

          redirect_to school_admin_school_path, alert: @alert, status: :see_other
        end
      end
    end

    def own_school = Queries::School::OwnSchoolQuery.new.call(school_id: current_actor.school_id)

    def regenerate
      UseCases::School::RegenerateSchoolCode.new(
        schools: Repositories::School::SchoolRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        policy: Policies::School::ManageSchoolStructurePolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end

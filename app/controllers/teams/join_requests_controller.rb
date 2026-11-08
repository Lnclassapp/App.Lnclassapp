# 🌐 DELIVERY · Teams::JoinRequestsController
# Rôle : l'équipe valide ou refuse un enseignant inscrit sans code, depuis la fiche ; retour à la fiche avec le message
# ADR  : 0026, 0028, 0063 · UDR : 0050
module Teams
  class JoinRequestsController < BaseController
    NOTICES = { "approve" => ".approved", "reject" => ".rejected" }.freeze

    # Une demande ne se décide que depuis la fiche de son établissement : toute autre URL répond 404.
    def update
      return render_not_found unless Queries::School::JoinRequestsQuery.new.in_school?(public_id: params[:public_id].to_s,
                                                                                       school_public_id: params[:school_public_id].to_s)

      decision = params[:decision].to_s
      result = review.call(actor: current_actor, public_id: params[:public_id], decision:)
      back = school_path(params[:school_public_id])
      return redirect_to(back, alert: conflict_message(result), status: :see_other) if result.code == :conflict
      return head(:unprocessable_entity) if result.code == :invalid

      render_result result, success: lambda { |request|
        redirect_to back, notice: t(NOTICES.fetch(decision), name: request.teacher_name), status: :see_other
      }
    end

    private

    # Un enseignant déjà rattaché entre-temps garde sa demande en attente : le dire, au lieu de « déjà traitée ».
    def conflict_message(result) = result.errors.fetch(:base, []).include?(:already_attached) ? t(".already_attached") : t(".already_decided")

    def review
      UseCases::School::ReviewJoinRequest.new(
        join_requests: Repositories::School::JoinRequestRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        policy: Policies::School::ManageSchoolPolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone,
        teacher_materials: Repositories::Identity::TeacherMaterialRepository.new
      )
    end
  end
end

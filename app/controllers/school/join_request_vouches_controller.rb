# 🌐 DELIVERY · School::JoinRequestVouchesController
# Rôle : « Je confirme » d'un enseignant actif pour un collègue en attente de son établissement ; ligne retirée et toast (stream)
# ADR  : 0026, 0028, 0063 · UDR : 0050
module School
  class JoinRequestVouchesController < AuthenticatedController
    allow_roles :teacher

    def create
      result = vouch.call(actor: current_actor, public_id: params[:public_id])
      return refuse_decided if result.code == :conflict

      render_result result, success: lambda { |request|
        @notice = t(".done", name: request.teacher_name)
        respond_to do |format|
          format.turbo_stream do
            @request = request
            @remaining = Queries::School::JoinRequestsQuery.new.for_colleague(teacher_id: current_actor.user_id)
          end
          format.html { redirect_to teacher_home_path, notice: @notice, status: :see_other }
        end
      }
    end

    private

    def refuse_decided
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: helpers.turbo_stream_toast(t(".already_decided"), type: :warning), status: :unprocessable_entity
        end
        format.html { redirect_to teacher_home_path, alert: t(".already_decided"), status: :see_other }
      end
    end

    def vouch
      UseCases::School::VouchForTeacher.new(
        join_requests: Repositories::School::JoinRequestRepository.new, schools: Repositories::School::SchoolRepository.new,
        referrals: Repositories::Identity::ReferralRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        policy: Policies::School::VouchPolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end

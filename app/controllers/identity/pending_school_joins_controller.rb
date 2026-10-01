# 🌐 DELIVERY · Identity::PendingSchoolJoinsController
# Rôle : « Rejoindre l'établissement » de l'écran d'attente : le code saisi rattache l'enseignant sans établissement (limité)
# ADR  : 0028, 0057, 0063, 0071 · UDR : 0050, 0056
module Identity
  class PendingSchoolJoinsController < AuthenticatedController
    skip_before_action :hold_pending_teacher
    rate_limit to: 10, within: 1.minute, by: -> { request.remote_ip }, with: -> { refuse_too_many }

    SCREEN = "identity/pending_accounts/show".freeze

    def create
      @form = @school_join = Dtos::School::SchoolJoinInput.new(school_code: params.expect(school_join: [ :school_code ])[:school_code])
      result = join.call(actor: current_actor, dto: @school_join)
      prepare_screen
      render_result result, form: SCREEN, success: lambda { |school|
        redirect_to teacher_classrooms_path, notice: t(".welcome", school: school.name), status: :see_other
      }
    end

    private

    # L'écran d'attente re-rendu : celui de l'enseignant sans établissement, sa demande refusée gardée au-dessus.
    def prepare_screen
      @case = :teacher
      @join_request = Queries::School::JoinRequestsQuery.new.status_for(teacher_id: current_actor.user_id)
    end

    # Au-delà de 10 essais par minute : l'état d'erreur à la place du formulaire, rien n'est cherché.
    def refuse_too_many
      @rate_limited = true
      @school_join = Dtos::School::SchoolJoinInput.new
      prepare_screen
      render SCREEN, status: :too_many_requests
    end

    def join
      UseCases::School::JoinSchoolWithCode.new(
        schools: Repositories::School::SchoolRepository.new, departures: Repositories::School::TeacherDepartureRepository.new,
        join_requests: Queries::School::JoinRequestsQuery.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        policy: Policies::School::JoinSchoolWithCodePolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end

# 🌐 DELIVERY · Teams::PushApprovalsController
# Rôle : « Valider l'envoi » d'un motif du plan du jour ; Turbo Stream (ligne du motif, historique, toast), redirection sans JavaScript
# ADR  : XXXX envois de notifications (§3.2, §4.4) · UDR : XXXX écran notifications de l'équipe (§3.4) · garde : celle de BaseController (équipe seule)
module Teams
  class PushApprovalsController < BaseController
    TOAST_TYPES = { approved: :success, conflict: :info, expired: :error, invalid: :info }.freeze

    # Un motif non validable (annonce, inconnu) : 404 ; un motif automatique ou sans élève : rien n'est écrit, un toast le dit.
    def create
      @motive = params[:motive].to_s
      result = approve.call(actor: current_actor, motive: @motive)
      return render_result(result, success: ->(_) { respond(:approved, result.value) }) if result.success? || %i[forbidden not_found].include?(result.code)

      respond(result.code, nil)
    end

    private

    # La ligne est relue après le geste : elle montre l'état réel (auteur et nombre enregistrés), y compris sur « déjà validé ».
    def respond(outcome, approval)
      now = Time.current
      @closed = UseCases::Communication::ApprovePushMotive.closed?(now)
      @entry = Queries::Communication::PushDailyPlanQuery.new.call(now:).find { it.motive == @motive }
      @approval = approval
      @toast_type = TOAST_TYPES.fetch(outcome)
      @toast = toast_message(outcome)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to teams_push_settings_path, flash: { (@toast_type == :error ? :alert : :notice) => @toast }, status: :see_other }
      end
    end

    def toast_message(outcome)
      case outcome
      when :approved then t(".approved", count: @approval.recipients_count)
      when :conflict then already_approved_message
      when :expired then t(".closed")
      else t("teams.push_plans.show.empty.title")
      end
    end

    # L'auteur et l'heure réels de la validation qui a gagné ; sans elle (purgée entre-temps), le simple état « Validé ».
    def already_approved_message
      approval = @entry&.approval
      return t("teams.push_plans.show.approved") if approval.nil?

      t(".already_approved", name: approval.by_name, time: helpers.l(approval.at, format: :hour_minute))
    end

    def approve
      UseCases::Communication::ApprovePushMotive.new(
        candidates: Queries::Communication::PushCandidates.new, deliveries: Repositories::Communication::PushDeliveryRepository.new,
        settings: Repositories::Communication::PushMotiveSettingRepository.new, approvals: Repositories::Communication::PushApprovalRepository.new,
        policy: Policies::Communication::ApprovePushPolicy.new, clock: Time.zone
      )
    end
  end
end

# 🌐 DELIVERY · Teams::PushMotiveSettingsController
# Rôle : un admin coche ou décoche « Automatique » sur un motif ; Turbo Stream (ligne, plan du jour, toast), redirection sans JavaScript
# ADR  : 0028 · XXXX envois de notifications (§4.1) · UDR : XXXX écran notifications de l'équipe (§3.3)
module Teams
  class PushMotiveSettingsController < BaseController
    def update
      result = update_setting.call(actor: current_actor, motive: params[:motive].to_s, automatic: automatic_param)
      result.success? ? respond_saved : respond_refused(result.code)
    end

    private

    def respond_saved
      load_page
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to teams_push_settings_path, notice: t(".saved"), status: :see_other }
      end
    end

    # Droit refusé (403) ou motif forgé hors AUTOMATABLE (422) : rien n'est écrit, un toast le dit, la ligne revient à l'état du serveur.
    def respond_refused(code)
      @refused = true
      load_page
      respond_to do |format|
        format.turbo_stream { render status: code == :forbidden ? :forbidden : :unprocessable_entity }
        format.html do
          next render_error_page(:forbidden) if code == :forbidden

          redirect_to teams_push_settings_path, alert: t(".failed"), status: :see_other
        end
      end
    end

    def load_page
      @page = Queries::Communication::PushSettingsQuery.new.call
      @mode = @page.modes.find { it.motive == params[:motive].to_s }
      @can_manage = Policies::Communication::ManagePushSettingsPolicy.new.call(actor: current_actor).success?
    end

    # La case envoie « 0 » puis « 1 » : seule la chaîne « 1 » (ou « true ») coche ; un tableau ou un hash forgé décoche.
    def automatic_param
      value = params[:automatic]
      value.is_a?(String) && ActiveModel::Type::Boolean.new.cast(value) == true
    end

    def update_setting
      UseCases::Communication::UpdatePushMotiveSetting.new(
        settings: Repositories::Communication::PushMotiveSettingRepository.new,
        policy: Policies::Communication::ManagePushSettingsPolicy.new, clock: Time.zone
      )
    end
  end
end

# 🌐 DELIVERY · Teams::PushSettingsController
# Rôle : la page « Notifications » de l'équipe : bandeau d'environnement, réglages des motifs, historique ; le plan du jour est un frame lu à part
# ADR  : 0028 · XXXX envois de notifications · UDR : XXXX écran notifications de l'équipe · garde : celle de BaseController (équipe seule, 403 sinon)
module Teams
  class PushSettingsController < BaseController
    # Toute l'équipe lit la page ; seul un admin peut en changer une case (ManagePushSettingsPolicy, rendue en `disabled` sinon).
    def show
      render_result Policies::Communication::ViewPushSettingsPolicy.new.call(actor: current_actor), success: lambda { |_|
        @page = Queries::Communication::PushSettingsQuery.new.call
        @can_manage = Policies::Communication::ManagePushSettingsPolicy.new.call(actor: current_actor).success?
      }
    end
  end
end

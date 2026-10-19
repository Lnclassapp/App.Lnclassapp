# 🌐 DELIVERY · Teams::ClassroomSettingsController
# Rôle : « Modifier la classe » du menu ⋮ d'une carte de la fiche d'un établissement (équipe, tout statut d'établissement)
# ADR  : 0098 · UDR : 0110, 0111
module Teams
  class ClassroomSettingsController < BaseController
    include ClassroomSettingsActions

    private

    def settings_school_public_id = params[:school_public_id]
    def saved_location = school_path(settings_school_public_id)
  end
end

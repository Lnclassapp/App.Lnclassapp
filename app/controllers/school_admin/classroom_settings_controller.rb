# 🌐 DELIVERY · SchoolAdmin::ClassroomSettingsController
# Rôle : « Modifier la classe » du menu ⋮ d'une carte de la page d'un niveau, sur le seul établissement actif de la direction
# ADR  : 0065, 0098 · UDR : 0110, 0111 · l'établissement est current_actor.school_id, jamais un paramètre
module SchoolAdmin
  class ClassroomSettingsController < BaseController
    include ClassroomSettingsActions

    private

    def settings_school_public_id
      @settings_school_public_id ||= Queries::School::OwnSchoolQuery.new.call(school_id: current_actor.school_id).public_id
    end

    def saved_location = school_admin_level_path(settings.level_slug)
  end
end

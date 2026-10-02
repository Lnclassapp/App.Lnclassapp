# 🌐 DELIVERY · SchoolAdmin::SchoolsController
# Rôle : « Établissement » de la direction : lien d'inscription des enseignants, puis le bloc « Classes par niveau »
# ADR  : 0006, 0071 · UDR : 0056 · l'établissement est celui du compte, jamais un paramètre
module SchoolAdmin
  class SchoolsController < BaseController
    def show
      @school = Queries::School::OwnSchoolQuery.new.call(school_id: current_actor.school_id)
      @level_classrooms = Queries::School::LevelClassroomsQuery.new.call(public_id: @school.public_id)
    end
  end
end

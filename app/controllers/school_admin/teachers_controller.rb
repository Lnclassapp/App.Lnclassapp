# 🌐 DELIVERY · SchoolAdmin::TeachersController
# Rôle : « Enseignants » de la direction, en lecture seule ; l'établissement est celui du compte, jamais un paramètre
# ADR  : 0065 · UDR : 0052
module SchoolAdmin
  class TeachersController < BaseController
    def index
      @overview = Queries::School::SchoolTeachersQuery.new.call(school_id: current_actor.school_id)
    end
  end
end

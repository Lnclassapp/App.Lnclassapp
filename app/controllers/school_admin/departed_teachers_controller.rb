# 🌐 DELIVERY · SchoolAdmin::DepartedTeachersController
# Rôle : « Enseignants retirés » de la direction, page sœur de « Enseignants » ; l'établissement est celui du compte
# ADR  : 0006, 0071 · UDR : 0056
module SchoolAdmin
  class DepartedTeachersController < BaseController
    def index
      @overview = Queries::School::DepartedTeachersQuery.new.call(school_id: current_actor.school_id)
    end
  end
end

# 🌐 DELIVERY · SchoolAdmin::SchoolsController
# Rôle : page « Établissement » : en-tête de l'établissement de l'acteur, frames différés du code (Lot G) et du personnel (Lot B)
# ADR  : 0057, 0066 · UDR : 0052
module SchoolAdmin
  class SchoolsController < BaseController
    def show
      @school = Queries::School::DirectionSchoolQuery.new.call(school_id: current_actor.school_id)
    end
  end
end

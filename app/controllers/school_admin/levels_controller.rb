# 🌐 DELIVERY · SchoolAdmin::LevelsController
# Rôle : page d'un niveau de la direction : les classes de l'année de ce niveau (archivées récentes comprises), dans son établissement ; 404 sinon
# ADR  : 0065, 0088 · UDR : 0074 (§3.8), 0083 · l'établissement vient du compte, le niveau de son slug figé ; ?archives=1 montre toutes les archivées
module SchoolAdmin
  class LevelsController < BaseController
    def show
      @school = Queries::School::OwnSchoolQuery.new.call(school_id: current_actor.school_id)
      @archives = params[:archives] == "1"
      @level = Queries::School::StudentWorkQuery.new.level(school_id: current_actor.school_id, slug: params[:slug], archives: @archives)
      render_not_found if @level.nil?
    end
  end
end

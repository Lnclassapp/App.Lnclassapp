# 🌐 DELIVERY · SchoolAdmin::LevelsController
# Rôle : page d'un niveau de la direction : les classes actives de l'année de ce niveau, dans son établissement ; 404 sinon
# ADR  : 0065 · UDR : 0072 (§3.8) · l'établissement vient du compte, le niveau de son slug figé
module SchoolAdmin
  class LevelsController < BaseController
    def show
      @level = Queries::School::StudentWorkQuery.new.level(school_id: current_actor.school_id, slug: params[:slug])
      render_not_found if @level.nil?
    end
  end
end

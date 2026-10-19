# 🌐 DELIVERY · SchoolAdmin::LevelsController
# Rôle : page d'un niveau de la direction : les classes de l'année de ce niveau (archivées récentes comprises), dans son établissement ; 404 sinon
# ADR  : 0065, 0088, 0092 · UDR : 0074 (§3.8), 0083, 0092 (§3.5) · l'établissement vient du compte, le niveau de son slug figé
module SchoolAdmin
  class LevelsController < BaseController
    def show
      @school = Queries::School::OwnSchoolQuery.new.call(school_id: current_actor.school_id)
      @archives = params[:archives] == "1"
      @level = Queries::School::StudentWorkQuery.new.level(school_id: current_actor.school_id, slug: params[:slug], archives: @archives)
      return render_not_found if @level.nil?

      # Menus d'archivage par la policy de la structure (UDR-0092 §3.5) ; ?archives=1 montre toutes les archivées.
      @manageable = gesture_allowed?(Policies::School::ManageSchoolStructurePolicy, @school)
      @rank_note = rank_note(@school, @manageable)
    end
  end
end

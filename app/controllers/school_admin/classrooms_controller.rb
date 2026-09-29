# 🌐 DELIVERY · SchoolAdmin::ClassroomsController
# Rôle : « Travail des élèves » (accueil de la direction) et page d'une classe, en lecture seule ; 404 hors de son établissement
# ADR  : 0006, 0065 · UDR : 0052
module SchoolAdmin
  class ClassroomsController < BaseController
    def index
      @overview = query.classrooms(school_id: current_actor.school_id)
    end

    def show
      @detail = query.classroom(school_id: current_actor.school_id, public_id: params[:public_id])
      render_not_found if @detail.nil?
    end

    private

    def query = Queries::School::StudentWorkQuery.new
  end
end

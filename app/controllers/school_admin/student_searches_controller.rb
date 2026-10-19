# 🌐 DELIVERY · SchoolAdmin::StudentSearchesController
# Rôle : « Chercher un élève » de la direction : par son nom, dans tout son établissement ; chaque résultat mène à sa classe
# ADR  : 0065, 0092 · UDR : 0094 · l'établissement est celui du compte ; moins de 3 lettres, aucune lecture des élèves
module SchoolAdmin
  class StudentSearchesController < BaseController
    MAX_LENGTH = 80

    def show
      @search = params[:q].to_s.squish.first(MAX_LENGTH)
      @searchable = Queries::School::StudentSearchQuery.searchable?(@search)
      rows = @searchable ? Queries::School::StudentSearchQuery.new.call(school_id: current_actor.school_id, term: @search) : []
      @truncated = rows.size > Queries::School::StudentSearchQuery::SHOWN
      @students = rows.first(Queries::School::StudentSearchQuery::SHOWN)
    end
  end
end

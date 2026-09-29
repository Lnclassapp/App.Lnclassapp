# 🌐 DELIVERY · SchoolAdmin::ClassroomsController
# Rôle : « Travail des élèves » (accueil de la direction) et page d'une classe, en lecture seule ; 404 hors de son établissement
# ADR  : 0006, 0065 · UDR : 0052, 0054 · `q` ne filtre que les élèves déjà lus de cette classe (FU-49)
module SchoolAdmin
  class ClassroomsController < BaseController
    def index
      @overview = query.classrooms(school_id: current_actor.school_id)
    end

    def show
      @detail = query.classroom(school_id: current_actor.school_id, public_id: params[:public_id])
      return render_not_found if @detail.nil?

      @search = params[:q].to_s.squish
      @students = matching_students(@detail.students, @search)
    end

    private

    def query = Queries::School::StudentWorkQuery.new

    # Même traitement que la recherche serveur (sans casse ni accents), appliqué aux élèves de la classe déjà lus :
    # la requête de la direction n'est pas modifiée.
    def matching_students(students, term)
      term = Queries::Shared::TextSearch.normalize(term)
      return students if term.empty?

      students.select { Queries::Shared::TextSearch.normalize(it.display_name).include?(term) }
    end
  end
end

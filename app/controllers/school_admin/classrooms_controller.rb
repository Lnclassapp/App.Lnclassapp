# 🌐 DELIVERY · SchoolAdmin::ClassroomsController
# Rôle : accueil de la direction (établissement, niveaux, bandeau d'arrivée) et page d'une classe : lien, nouveaux, retrait ; 404 hors établissement
# ADR  : 0006, 0065, 0077, 0078, 0083 · UDR : 0052, 0054, 0070, 0071, 0074, 0079 · `q` ne filtre que les élèves déjà lus de cette classe (FU-49)
module SchoolAdmin
  class ClassroomsController < BaseController
    def index
      @home = Queries::School::DirectionHomeQuery.new.call(school_id: current_actor.school_id)
      # UDR-0070 §3.3 : les directions arrivées depuis moins de 7 jours, sauf soi.
      @arrivals = Queries::School::SchoolStaffQuery.new.recent_arrivals(
        school_id: current_actor.school_id, since: Entities::School::Staff::NEWCOMER_DAYS.days.ago, except_user_id: current_actor.user_id
      )
      @announcements = announcements
    end

    # La classe n'est lue que dans l'établissement de la direction et active : là où ManageClassroomMembersPolicy lui
    # accorde le lien et le retrait (UDR-0079 §3.6, §3.7), que leurs contrôleurs vérifient de nouveau à chaque geste.
    def show
      @detail = query.classroom(school_id: current_actor.school_id, public_id: params[:public_id])
      return render_not_found if @detail.nil?

      @search = params[:q].to_s.squish
      @students = matching_students(@detail.members, @search)
    end

    private

    def query = Queries::School::StudentWorkQuery.new

    # UDR-0074 §3.10 : le carrousel de l'élève, par la règle de lecture des annonces (ADR-0078 §4.3), lu en direct.
    def announcements
      reader = Queries::Communication::ReadableMessages.new.reader_for(actor: current_actor)
      Queries::Communication::InboxQuery.new.carousel(reader:, now: Time.current)
    end

    # Même traitement que la recherche serveur (sans casse ni accents), appliqué aux élèves de la classe déjà lus :
    # la requête de la direction n'est pas modifiée.
    def matching_students(students, term)
      term = Queries::Shared::TextSearch.normalize(term)
      return students if term.empty?

      students.select { Queries::Shared::TextSearch.normalize(it.display_name).include?(term) }
    end
  end
end

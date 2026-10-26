# 🌐 DELIVERY · Classroom::TeacherHomesController
# Rôle : accueil enseignant (TR-05) : classes, cours, annonces, « Cette semaine » et Historique, « Inviter » ; sans école : l'écran de sortie
# ADR  : 0026, 0030, 0040, 0063, 0078, 0094 · UDR : 0006, 0026, 0050, 0077, 0098, écrans enseignant §3.3
module Classroom
  class TeacherHomesController < AuthenticatedController
    include ColleagueInvitation

    allow_roles :teacher

    # HomeDestination tranche : l'écran de sortie, qui ne redirige jamais ici (TR-02) ; sans classe, l'accueil porte « Ajoutez vos classes ».
    def show
      return redirect_to_home unless Queries::Identity::HomeDestinationQuery.new.call(actor: current_actor) == :teacher_home

      # L'établissement courant seulement (ADR-0094 §4.6) : deux « 6ème 1 » ne se côtoient jamais.
      scope = { teacher_id: current_actor.user_id, school_id: current_actor.school_id }
      @home = Queries::Classroom::TeacherHomeQuery.new.call(**scope)
      follow_ups = Queries::Classroom::TeacherFollowUpsQuery.new.call(**scope)
      @follow_ups = follow_ups.week
      @history = follow_ups.history
      @announcements = announcements
      @invite = colleague_invite
      # Seul un enseignant qui peut inviter (établissement actif) peut se porter garant : la même condition (ADR-0063).
      @pending_colleagues = Queries::School::JoinRequestsQuery.new.for_colleague(**scope) if @invite
    end

    private

    # UDR-0077 §3.1 : le carrousel de l'élève, par la règle de lecture, en un nombre fixe de requêtes (ADR-0067).
    def announcements
      reader = Queries::Communication::ReadableMessages.new.reader_for(actor: current_actor)
      Queries::Communication::InboxQuery.new.carousel(reader:, now: Time.current)
    end
  end
end

# 🌐 DELIVERY · Classroom::TeacherHomesController
# Rôle : accueil enseignant (TR-05) et « Inviter un collègue » ; configuration non terminée ou sans école : un saut vers son accueil
# ADR  : 0026, 0030, 0040, 0063 · UDR : 0006, 0026, 0050
module Classroom
  class TeacherHomesController < AuthenticatedController
    include ColleagueInvitation

    allow_roles :teacher

    # HomeDestination tranche : la déclaration des classes, ou l'écran de sortie, qui ne redirigent jamais ici (TR-02).
    def show
      return redirect_to_home unless Queries::Identity::HomeDestinationQuery.new.call(actor: current_actor) == :teacher_home

      @home = Queries::Classroom::TeacherHomeQuery.new.call(teacher_id: current_actor.user_id)
      @invite = colleague_invite
    end
  end
end

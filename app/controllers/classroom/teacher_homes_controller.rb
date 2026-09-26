# 🌐 DELIVERY · Classroom::TeacherHomesController
# Rôle : accueil enseignant (TR-05) ; configuration non terminée ou sans école principale, un seul saut vers son accueil réel
# ADR  : 0026, 0030, 0040 · UDR : 0006, 0026
module Classroom
  class TeacherHomesController < AuthenticatedController
    allow_roles :teacher

    # HomeDestination tranche : la déclaration des classes, ou l'écran de sortie, qui ne redirigent jamais ici (TR-02).
    def show
      return redirect_to_home unless Queries::Identity::HomeDestinationQuery.new.call(actor: current_actor) == :teacher_home

      @home = Queries::Classroom::TeacherHomeQuery.new.call(teacher_id: current_actor.user_id)
    end
  end
end

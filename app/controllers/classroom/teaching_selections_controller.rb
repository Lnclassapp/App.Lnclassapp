# 🌐 DELIVERY · Classroom::TeachingSelectionsController
# Rôle : « Quelles classes enseignez-vous ? » ; sans école principale, l'écran de sortie, sans boucle de redirection
# ADR  : 0028, 0030, 0040, 0063 · UDR : 0025
module Classroom
  class TeachingSelectionsController < AuthenticatedController
    allow_roles :teacher

    # Un enseignant sans école n'arrive pas ici : AuthenticatedController le retient sur l'écran d'attente (ADR-0063, TR-02).
    def index
      @selection = Queries::Classroom::TeachingSelectionQuery.new.call(teacher_id: current_actor.user_id,
                                                                       school_id: current_actor.school_id)
    end
  end
end
